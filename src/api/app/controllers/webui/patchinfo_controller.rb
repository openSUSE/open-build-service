require 'builder'

class Webui::PatchinfoController < Webui::WebuiController
  include Webui::PackageHelper
  before_action :set_project
  before_action :get_binaries, except: [:show, :delete, :new_tracker]
  before_action :require_exists, except: [:new_patchinfo, :new_tracker]
  before_action :require_login, except: [:show]

  def new_patchinfo
    authorize @project, :update?, policy_class: ProjectPolicy

    unless @project.exists_package?('patchinfo')
      unless Patchinfo.new.create_patchinfo(@project.name, nil)
        flash[:error] = 'Error creating patchinfo'
        redirect_to(controller: 'project', action: 'show', project: @project) && return
      end
    end
    @package = @project.packages.find_by_name('patchinfo')
    @file = @package.patchinfo
    unless @file
      flash[:error] = "Patchinfo not found for #{params[:project]}"
      redirect_to(controller: 'package', action: 'show', project: @project, package: @package) && return
    end

    read_patchinfo
    @binaries.each { |bin| @binarylist.delete(bin) }
  end

  def updatepatchinfo
    authorize @project, :update?

    Patchinfo.new.cmd_update_patchinfo(params[:project], params[:package])
    redirect_to action: 'edit_patchinfo', project: @project, package: @package
  end

  def edit_patchinfo
    read_patchinfo
    @tracker = ::Configuration.default_tracker
    @binaries.each { |bin| @binarylist.delete(bin) }
  end

  def show
    read_patchinfo
    @pkg_names = @project.packages.pluck(:name)
    @pkg_names.delete('patchinfo')
    @packager = User.where(login: @packager).first
  end

  def save
    flash[:error] = nil
    # Note: At this point a patchinfo already got created by
    #       Patchinfo.new.create_patchinfo in the new_patchinfo action
    unless valid_summary?(params[:summary])
      flash[:error] = '|| Summary is too short (should have more than 10 signs)'
    end
    unless valid_description?(params[:description])
      flash[:error] = "#{flash[:error]} || Description is too short (should have more than 50 signs and longer than summary)"
    end

    if flash[:error].nil?
      issues = []
      params[:issueid].to_a.each_with_index do |new_issue, index|
        issues << [
          new_issue,
          params[:issuetracker][index],
          params[:issuesum][index]
        ]
      end
      node = Builder::XmlMarkup.new(indent: 2)
      attrs = {
        incident: @package.project.name.gsub(/.*:/, '')
      }
      attrs[:version] = params[:version] if params[:version].present?
      xml = node.patchinfo(attrs) do
        params[:selected_binaries].to_a.each do |binary|
          node.binary(binary) if binary.present?
        end
        node.name(params[:name]) if params[:name].present?
        node.packager(params[:packager])
        issues.to_a.each do |issue|
          unless IssueTracker.find_by_name(issue[1])
            flash[:error] = "Unknown Issue tracker #{issue[1]}"
            render action: 'edit_patchinfo', project: @project, package: @package
            return
          end
          # people tend to enter entire cve strings instead of just the name
          issue[0].gsub!(/^(CVE|cve)-/, '') if issue[1] == 'cve'
          node.issue(issue[2], tracker: issue[1], id: issue[0])
        end
        node.category(params[:category].try(:strip))
        node.rating(params[:rating].try(:strip))
        node.summary(params[:summary].try(:strip))
        node.description(params[:description].gsub("\r\n", "\n"))
        @file.each(:package) do |pkg|
          node.package(pkg.text)
        end
        @file.each(:releasetarget) do |release_target|
          attributes = { project: release_target.value(:project) }
          attributes[:repository] = release_target.value(:repository) if release_target.value(:repository)
          node.releasetarget(attributes)
        end
        node.message params[:message].gsub("\r\n", "\n") if params[:message].present?
        node.reboot_needed if params[:reboot]
        node.relogin_needed if params[:relogin]
        node.zypp_restart_needed if params[:zypp_restart_needed]
        node.stopped params[:block_reason] if params[:block] == 'true'
      end
      begin
        authorize @package, :update?

        begin
          Package.verify_file!(@package, '_patchinfo', xml)
        rescue APIError => e
          flash[:error] = "patchinfo is invalid: #{e.message}"
          render action: 'edit_patchinfo', project: @project, package: @package
          return
        end

        Backend::Api::Sources::Package.write_patchinfo(@package.project.name, @package.name, User.current.login, xml)

        @package.sources_changed(wait_for_update: true) # wait for indexing for special files

        flash[:notice] = "Successfully edited #{@package}"
      rescue Timeout::Error
        flash[:error] = 'Timeout when saving file. Please try again.'
      end

      redirect_to controller: 'patchinfo', action: 'show',
                  project: @project.name, package: @package
    else
      @tracker = params[:tracker]
      @version = params[:version]
      @packager = params[:packager]
      @binaries = params[:selected_binaries] || []
      @binarylist = params[:available_binaries] || []
      @issues = []
      params[:issueid].to_a.each_with_index do |new_issue, index|
        @issues << [
          new_issue,
          params[:issuetracker][index],
          params[:issueurl][index],
          params[:issuesum][index]
        ]
      end
      @category = params[:category]
      @rating = params[:rating]
      @summary = params[:summary]
      @description = params[:description]
      @message = params[:message]
      @relogin = params[:relogin]
      @reboot = params[:reboot]
      @zypp_restart_needed = params[:zypp_restart_needed]
      @block = params[:block]
      @block_reason = params[:block_reason]
      render action: 'edit_patchinfo', project: @project, package: @package
    end
  rescue ActiveXML::Transport::ForbiddenError
    flash[:error] = 'No permission to edit the patchinfo-file.'
    redirect_to action: 'show', project: @project.name, package: @package.name
  end

  def remove
    authorize @package, :destroy?

    if @package.check_weak_dependencies? && @package.destroy
      redirect_to(project_show_path(@project), notice: 'Patchinfo was successfully removed.')
    else
      redirect_to(patchinfo_show_path(package: @package, project: @project),
                  notice: "Patchinfo can't be removed: #{@package.errors.full_messages.to_sentence}")
    end
  end

  def delete_dialog
    render_dialog
  end

  def new_tracker
    # collection with all informations of the new issues
    issue_collection = []
    error = ''
    invalid_format = ''
    # params[:issues] = list of new issues to add
    params[:issues].each do |new_issue|
      issue = IssueTracker::IssueTrackerHelper.new(new_issue)
      if issue.valid?
        begin
          issue_tracker = IssueTracker.find_by_name(issue.tracker)
          if issue_tracker
            issue.url = issue_tracker.show_url_for(issue.issue_id)
            issue_summary = get_issue_summary(issue.tracker, issue.issue_id)
            unless issue_summary
              invalid_format += "#{issue.tracker} "
              next
            end
            issue.summary = issue_summary
            issue_collection << issue.to_a
          else
            error << "#{issue.tracker} is not a valid tracker.\n"
          end
        rescue ActiveXML::Transport::NotFoundError
          invalid_format += "#{issue.tracker} "
        end
      else
        invalid_format += "#{issue.tracker} "
      end
    end

    error += print_invalid_format(invalid_format) unless invalid_format.empty?

    render json: { error: error, issues: issue_collection }
  end

  private

  def print_invalid_format(invalid_format)
    "#{invalid_format.strip} has no valid format. (Correct formats are e.g. " \
             'boo#123456, CVE-1234-5678 and the string has to be a comma-separated list)'
  end

  def read_patchinfo
    @binaries = []
    @file.each(:binary) do |binaries|
      @binaries << binaries.text
    end
    @packager = @file.value(:packager)
    @version = @file.value(:version)

    if params[:issueid]
      @issues = params[:issue].to_a << params[:issueid]
    else
      @issues = []
      @file.each(:issue) do |a|
        if a.text == ''
          # old uploaded patchinfos could have broken tracker-names like "bnc "
          # instead of "bnc". Catch these.
          begin
            a.text = get_issue_summary(a.value(:tracker), a.value(:id))
          rescue ActiveXML::Transport::NotFoundError
            a.text = 'PLEASE CHECK THE FORMAT OF THE ISSUE'
          end
        end

        issue_tracker = IssueTracker.find_by_name(a.value(:tracker)).
                        try(:show_url_for, a.value(:id)).to_s

        @issues << [
          a.value(:tracker),
          a.value(:id),
          issue_tracker,
          a.text
        ]
      end
    end
    @category = @file.value(:category)
    @rating = @file.value(:rating)
    @summary = @file.value(:summary)
    @name = @file.value(:name)

    @description = @file.value(:description)
    @message = @file.value(:message)
    @relogin = @file.has_element?('relogin_needed')
    @reboot = @file.has_element?('reboot_needed')
    @zypp_restart_needed = @file.has_element?('zypp_restart_needed')
    return unless @file.has_element?('stopped')
    @block = true
    @block_reason = @file.value(:stopped)
  end

  def valid_summary?(name)
    name && name.length > 10
  end

  def valid_description?(name)
    name &&
      name.length > [params[:summary].length, 50].max
  end

  def get_issue_summary(tracker, issueid)
    issue_summary = IssueTracker::IssueSummary.new(tracker, issueid)
    return unless issue_summary.issue_tracker
    return unless issue_summary.belongs_bug_to_tracker?
    issue_summary.issue_summary
  end

  def get_binaries
    @binarylist = []
    binary_list = Xmlhash.parse(Backend::Api::Build::Project.binarylist(params[:project]))
    binary_list.elements('result') do |result|
      result.elements('binarylist') do |list|
        list.elements('binary') do |bin|
          next if ['rpmlint.log', 'updateinfo.xml'].include?(bin['filename'])
          @binarylist << bin['filename'].sub(/-[^-]*-[^-]*.rpm$/, '')
        end
      end
    end
    @binarylist.uniq!
  end

  def require_exists
    if params[:package].present?
      begin
        @package = Package.get_by_project_and_name(params[:project], params[:package], use_source: false)
      rescue Package::UnknownObjectError
        flash[:error] = "Patchinfo '#{params[:package]}' not found in project '#{params[:project]}'"
        redirect_to project_show_path(project: params[:project])
        return
      end
    end

    unless @package && @package.patchinfo
      # FIXME: should work for remote packages
      flash[:error] = "Patchinfo not found for #{params[:project]}"
      redirect_to(controller: 'package', action: 'show', project: @project, package: @package) && return
    end
    @patchinfo = @file = @package.patchinfo
  end
end
