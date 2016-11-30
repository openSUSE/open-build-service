class Webui::PatchinfoController < Webui::WebuiController
  include Webui::PackageHelper
  before_action :set_project
  before_action :get_binaries, except: [:show, :delete]
  before_action :require_exists, except: [:new_patchinfo]
  before_action :require_login, except: [:show]

  def new_patchinfo
    unless User.current.can_create_package_in? @project
      flash[:error] = 'No permission to create packages'
      redirect_to(controller: 'project', action: 'show', project: @project) && return
    end

    unless @project.exists_package? 'patchinfo'
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

  def read_patchinfo
    @binaries = Array.new
    @file.each(:binary) do |binaries|
      @binaries << binaries.text
    end
    @binary = []
    @packager = @file.value(:packager)

    if params[:issueid]
      @issues = params[:issue].to_a << params[:issueid]
    else
      @issues = []
      @file.each(:issue) do |a|
        if a.text == ''
          # old uploaded patchinfos could have broken tracker-names like "bnc "
          # instead of "bnc". Catch these.
          begin
            a.text = get_issue_sum(a.value(:tracker), a.value(:id))
          rescue ActiveXML::Transport::NotFoundError
            a.text = 'PLEASE CHECK THE FORMAT OF THE ISSUE'
          end
        end

        issueurl = IssueTracker.find_by_name(a.value(:tracker)).
          try(:show_url_for, a.value(:id)).to_s

        @issues << [
          a.value(:tracker),
          a.value(:id),
          issueurl,
          a.text
        ]
      end
    end
    @category = @file.value(:category)
    @rating = @file.value(:rating)
    @summary = @file.value(:summary)
    @name = @file.value(:name)

    @description = @file.value(:description)
    @relogin = @file.has_element?('relogin_needed')
    @reboot = @file.has_element?('reboot_needed')
    @zypp_restart_needed = @file.has_element?('zypp_restart_needed')
    if @file.has_element?('stopped')
      @block = true
      @block_reason = @file.value(:stopped)
    end
  end

  def save
    begin
      required_parameters :project, :package
      flash[:error] = nil
      # Note: At this point a patchinfo already got created by
      #       Patchinfo.new.create_patchinfo in the new_patchinfo action
      unless valid_summary? params[:summary]
        flash[:error] = "|| Summary is too short (should have more than 10 signs)"
      end
      unless valid_description? params[:description]
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
        xml = node.patchinfo(attrs) do
          params[:selected_binaries].to_a.each do |binary|
            unless binary.blank?
              node.binary(binary)
            end
          end
          node.name params[:name] unless params[:name].blank?
          node.packager params[:packager]
          issues.to_a.each do |issue|
            unless IssueTracker.find_by_name(issue[1])
              flash[:error] = "Unknown Issue tracker #{issue[1]}"
              render action: 'edit_patchinfo', project: @project, package: @package
              return
            end
            # people tend to enter entire cve strings instead of just the name
            issue[0].gsub!(/^(CVE|cve)-/, '') if issue[1] == "cve"
            node.issue(issue[2], tracker: issue[1], id: issue[0])
          end
          node.category params[:category]
          node.rating params[:rating]
          node.summary params[:summary]
          node.description params[:description].gsub("\r\n", "\n")
          node.reboot_needed if params[:reboot]
          node.relogin_needed if params[:relogin]
          node.zypp_restart_needed if params[:zypp_restart_needed]
          if params[:block] == 'true'
            node.stopped params[:block_reason]
          end
        end
        begin
          authorize @package, :update?

          begin
            Package.verify_file!(@package, '_patchinfo', xml)
          rescue APIException => e
            flash[:error] = "patchinfo is invalid: #{e.message}"
            render action: 'edit_patchinfo', project: @project, package: @package
            return
          end

          Suse::Backend.put @package.source_path('_patchinfo', user: User.current.login), xml

          @package.sources_changed(wait_for_update: true) # wait for indexing for special files

          flash[:notice] = "Successfully edited #{@package}"
        rescue Timeout::Error
          flash[:error] = 'Timeout when saving file. Please try again.'
        end

        redirect_to controller: 'patchinfo', action: 'show',
                    project: @project.name, package: @package
      else
        @tracker = params[:tracker]
        @packager = params[:packager]
        @binaries = params[:selected_binaries]
        @binarylist = params[:available_binaries]
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
  end

  def remove
    authorize @package, :destroy?

    if @package.check_weak_dependencies? && @package.destroy
      redirect_to(project_show_path(@project), notice: "Patchinfo was successfully removed.")
    else
      redirect_to(patchinfo_show_path(package: @package, project: @project),
                  notice: "Patchinfo can't be removed: #{@package.errors.full_messages.to_sentence}")
    end
  end

  def delete_dialog
    render_dialog
  end

  def valid_summary?(name)
    name && name.length > 10
  end

  def valid_description?(name)
    name &&
      name.length > [params[:summary].length, 50].max
  end

  def new_tracker
    # collection with all informations of the new issues
    issue_collection = []
    error = ''
    invalid_format = ''
    # params[:issues] = list of new issues to add
    params[:issues].each do |new_issue|
      # issue = collecting all informations of an new issue
      issue = []
      if new_issue.starts_with? 'CVE-'
        issue[0] = 'cve'
        issue[1] = new_issue
      else
        issue = new_issue.split('#')
      end
      if issue.length > 1
        begin

          issueurl = IssueTracker.find_by_name(issue[0])
          if issueurl
            Rails.logger.debug "URL2 #{issueurl.inspect}"
            issue << issueurl.show_url_for(issue[1])
            issuesum = get_issue_sum(issue[0], issue[1])
            unless issuesum
              invalid_format += "#{issue[0]} "
              next
            end
            issue << issuesum
            issue_collection << issue
          else
            error << "#{issue[0]} is not a valid tracker.\n"
          end
        rescue ActiveXML::Transport::NotFoundError
          invalid_format += "#{issue[0]} "
        end
      else
        invalid_format += "#{issue[0]} "
      end
    end
    if !invalid_format.empty?
      error += "#{invalid_format} has no valid format. (Correct formats are e.g. " +
               "boo#123456, CVE-1234-5678 and the string has to be a comma-separated list)"
    end
    render json: { error: error, issues: issue_collection }
  end

  # returns issue summary of an issue
  # returns empty string in case of ActiveXML::Transport::Error exception
  # returns nil in case of error (bug mismatches tracker result regex)
  def get_issue_sum(tracker, issueid)
    if !issueid.starts_with? 'CVE-'
      bug = tracker + '#' + issueid
    else
      bug = issueid
    end

    issue_tracker = IssueTracker.find_by(name: tracker)
    return nil unless issue_tracker

    if bug.match(/^#{issue_tracker.regex}$/)
      issue = Issue.find_or_create_by_name_and_tracker( issueid, issue_tracker.name )
      if issue && issue.summary.blank?
        issue.fetch_updates
      end
      if issue.summary
        return issue.summary.gsub(/\\|'/) { '' }
      end
    else
      return nil
    end
    ''
  end

  private

  def get_binaries
    @binarylist = []
    binary_list = Buildresult.find(project: params[:project], view: 'binarylist')
    binary_list.to_hash.elements('result') do |result|
      result.elements('binarylist') do |list|
        list.elements('binary') do |bin|
          next if ["rpmlint.log", "updateinfo.xml"].include?(bin["filename"])
          @binarylist << bin['filename'].sub(/-[^-]*-[^-]*.rpm$/, '')
        end
      end
    end
    @binarylist.uniq!
  end

  def require_exists
    unless params[:package].blank?
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
