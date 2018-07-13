class SourceProjectPackageMetaController < SourceController
  before_action :require_package_name, only: [:show, :update]
  before_action :set_rdata, only: [:update]
  before_action :validate_project_name, only: [:update]
  before_action :validate_package_name, only: [:update]
  validate_action update: { request: :package, response: :status }

  def set_rdata
    @rdata = Xmlhash.parse(request.raw_post)
  end

  def validate_package_name
    err_message = 'package name in xml data does not match resource path component'
    err_code = 'package_name_mismatch'
    render_error status: 400, errorcode: err_code, message: err_message if @rdata['name'] && @rdata['name'] != @package_name
  end

  def validate_project_name
    err_message = 'project name in xml data does not match resource path component'
    err_code = 'project_name_mismatch'
    render_error status: 400, errorcode: err_code, message: err_message if @rdata['project'] && @rdata['project'] != @project_name
  end

  def require_package_name
    required_parameters :project, :package

    @project_name = params[:project]
    @package_name = params[:package]

    valid_package_name! @package_name
  end

  # GET /source/:project/:package/_meta
  def show
    pack = Package.get_by_project_and_name(@project_name, @package_name, use_source: false)

    if params.key?(:meta) || params.key?(:rev) || params.key?(:view) || pack.nil?
      # check if this comes from a remote project, also true for _project package
      # or if meta is specified we need to fetch the meta from the backend
      path = request.path_info
      path += build_query_from_hash(params, [:meta, :rev, :view])
      pass_to_backend path
      return
    end

    render xml: pack.to_axml
  end

  # PUT /source/:project/:package/_meta
  def update
    # check for project
    if Package.exists_by_project_and_name(@project_name, @package_name, follow_project_links: false)
      pkg = Package.get_by_project_and_name(@project_name, @package_name, use_source: false)
      unless User.current.can_modify?(pkg)
        render_error status: 403, errorcode: 'change_package_no_permission',
                     message: "no permission to modify package '#{pkg.project.name}'/#{pkg.name}"
        return
      end

      if pkg && !pkg.disabled_for?('sourceaccess', nil, nil)
        if FlagHelper.xml_disabled_for?(@rdata, 'sourceaccess') && !User.current.is_admin?
          render_error status: 403, errorcode: 'change_package_protection_level',
                       message: 'admin rights are required to raise the protection level of a package'
          return
        end
      end
    else
      prj = Project.get_by_name(@project_name)
      unless prj.is_a?(Project) && User.current.can_create_package_in?(prj)
        render_error status: 403, errorcode: 'create_package_no_permission',
                     message: "no permission to create a package in project '#{@project_name}'"
        return
      end
      pkg = prj.packages.new(name: @package_name)
    end

    pkg.set_comment(params[:comment])
    pkg.update_from_xml(@rdata)
    render_ok
  end
end
