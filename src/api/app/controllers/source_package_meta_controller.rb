class SourcePackageMetaController < SourceController
  # override the ApplicationController version
  # to have meaningful error messages
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  validate_action update: { request: :package, response: :status }
  before_action :require_valid_project_name
  before_action :require_package_name, only: %i[show update]
  before_action :set_request_data, only: [:update]

  before_action only: [:update] do
    validate_xml_content @request_data['project'],
                         @project_name,
                         'project_name_mismatch',
                         'project name in xml data does not match resource path component'
    validate_xml_content @request_data['name'],
                         @package_name,
                         'package_name_mismatch',
                         'package name in xml data does not match resource path component'
  end

  # GET /source/:project/:package/_meta
  def show
    if params.key?(:deleted)
      validate_read_access_of_deleted_package(@project_name, @package_name)
    else
      pack = Package.get_by_project_and_name(@project_name, @package_name, use_source: false)
    end

    # Let the backend answer for deleted or remote packages. For specific revisions or the blame view. Or if the meta parameter is used.
    if params.key?(:deleted) || params.key?(:meta) || params.key?(:rev) || params.key?(:view) || pack.nil?
      path = request.path_info
      path += build_query_from_hash(params, %i[deleted meta rev view])
      pass_to_backend(path)
      return
    end

    render xml: pack.to_axml
  end

  # PUT /source/:project/:package/_meta
  def update
    # check for project
    if Package.exists_by_project_and_name(@project_name, @package_name, follow_project_links: false)
      pkg = Package.get_by_project_and_name(@project_name, @package_name, use_source: false)

      authorize pkg, :update?

      change_package_protection_level?(pkg)
    else
      prj = Project.get_by_name(@project_name)
      # necessary to pass the policy_class here
      # if its remote prj is a string
      authorize prj, :update?, policy_class: ProjectPolicy
      pkg = prj.packages.new(name: @package_name)
    end

    pkg.comment = params[:comment]
    pkg.update_from_xml(@request_data)
    render_ok
  end

  private

  def change_package_protection_level?(pkg)
    # TODO: use pundit
    raise ChangePackageProtectionLevelError if pkg && !pkg.disabled_for?('sourceaccess', nil, nil) && FlagHelper.xml_disabled_for?(@request_data, 'sourceaccess') && !User.admin_session?
  end

  def require_package_name
    required_parameters :project, :package

    @project_name = params[:project]
    @package_name = params[:package]

    valid_package_name!(@package_name)
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore == :package_policy ? :package : :project

    render_error status: 403,
                 errorcode: "update_#{policy_name}_not_authorized",
                 message: "You are not authorized to update this #{policy_name}"
  end
end
