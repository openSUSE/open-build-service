require 'builder'

class Webui::PatchinfoController < Webui::WebuiController
  include Webui::PackageHelper
  before_action :set_project
  before_action :set_binaries, except: %i[show destroy new_tracker]
  before_action :require_package, except: %i[create new_tracker]
  before_action :require_exists, except: %i[create new_tracker]
  before_action :require_login, except: [:show]
  before_action :set_patchinfo, only: %i[show edit]

  rescue_from Package::UnknownObjectError do
    flash[:error] = "Patchinfo '#{elide(params[:package])}' not found in project '#{elide(params[:project])}'"
    redirect_to project_show_path(project: @project)
  end

  def show
    @pkg_names = @project.packages.pluck(:name)
    @pkg_names.delete('patchinfo')
    @packager = User.where(login: @patchinfo.packager).first
  end

  def edit
    # TODO: check that @tracker has sense if it's coming from create (new_patchinfo) action
    @tracker = ::Configuration.default_tracker
    @patchinfo.binaries.each { |bin| @binarylist.delete(bin) }
  end

  def create
    authorize @project, :update?, policy_class: ProjectPolicy

    if !@project.exists_package?('patchinfo') && !Patchinfo.new.create_patchinfo(@project.name, nil)
      flash[:error] = 'Error creating patchinfo'
      redirect_to(controller: 'project', action: 'show', project: @project) && return
    end
    @package = @project.packages.find_by_name('patchinfo')
    unless @package.patchinfo
      flash[:error] = "Patchinfo not found for #{elide(params[:project])}"
      redirect_to(controller: 'package', action: 'show', project: @project, package: @package) && return
    end
    redirect_to edit_patchinfo_path(project: @project, package: @package)
  end

  def update
    authorize @package, :update?
    @patchinfo = Patchinfo.new(patchinfo_params)
    if @patchinfo.valid?
      xml = @patchinfo.to_xml(@project, @package)
      begin
        Package.verify_file!(@package, '_patchinfo', xml)
        Backend::Api::Sources::Package.write_patchinfo(@package.project.name, @package.name, User.session.login, xml)
        @package.sources_changed(wait_for_update: true) # wait for indexing for special files
      rescue APIError, Timeout::Error => e
        flash[:error] = "patchinfo is invalid: #{e.message}"
        flash[:error] = 'Timeout when saving file. Please try again.' if e.is_a?(Timeout::Error)
        render action: :edit, project: @project, package: @package
        return
      end

      flash[:success] = "Successfully edited #{elide(@package.name)}"
      redirect_to controller: 'patchinfo', action: 'show', project: @project.name, package: @package
    else
      flash[:error] = @patchinfo.errors.full_messages.to_sentence
      @patchinfo.binaries.to_a.each { |bin| @binarylist.delete(bin) }
      render action: :edit, project: @project, package: @package
    end
  rescue Backend::Error
    flash[:error] = 'No permission to edit the patchinfo-file.'
    redirect_to action: 'show', project: @project.name, package: @package.name
  end

  def destroy
    authorize @package, :destroy?

    if @package.check_weak_dependencies? && @package.destroy
      redirect_to(project_show_path(@project), success: 'Patchinfo was successfully removed.')
    else
      redirect_to(show_patchinfo_path(package: @package, project: @project),
                  notice: "Patchinfo can't be removed: #{@package.errors.full_messages.to_sentence}")
    end
  end

  def update_issues
    authorize @project, :update?

    Patchinfo.new.cmd_update_patchinfo(params[:project], params[:package], 'updated via update_issues call')
    redirect_to edit_patchinfo_path(project: @project, package: @package)
  end

  def new_tracker
    # collection with all informations of the new issues
    issue_collection = []
    error = ''
    invalid_format = ''
    # params[:issues] = list of new issues to add
    params[:issues] ||= []
    params[:issues].each do |new_issue|
      issue = IssueTracker::IssueTrackerHelper.new(new_issue)
      if issue.valid?
        begin
          issue_tracker = IssueTracker.find_by_name(issue.tracker)
          if issue_tracker
            issue.url = issue_tracker.show_url_for(issue.issue_id)
            summary = IssueTracker::IssueSummary.new(issue.tracker, issue.issue_id)
            unless summary.belongs_bug_to_tracker?
              invalid_format += "#{issue.tracker} "
              next
            end
            issue.summary = summary.issue_summary
            issue_collection << issue.to_a
          else
            error << "#{issue.tracker} is not a valid tracker.\n"
          end
        rescue Backend::NotFoundError
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

  def set_binaries
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
    return if @package && @package.patchinfo

    # FIXME: should work for remote packages
    flash[:error] = "Patchinfo not found for #{@project.name}"
    redirect_to(controller: 'package', action: 'show', project: @project, package: @package)
  end

  def set_patchinfo
    patchinfo_xml = Xmlhash.parse(@package.patchinfo.document.to_xml)
    @patchinfo = Patchinfo.new.load_from_xml(patchinfo_xml)
  end

  def patchinfo_params
    params.require(:patchinfo).permit(:summary, :description, :packager, :category, :rating, :name, :version, :message,
                                      :relogin_needed, :reboot_needed, :zypp_restart_needed, :block, :block_reason,
                                      binaries: [], issueid: [], issueurl: [], issuetracker: [], issuesum: [])
  end
end
