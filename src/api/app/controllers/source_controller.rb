require 'builder/xchar'

class SourceController < ApplicationController
  include MaintenanceHelper
  include ValidationHelper

  include Source::Errors

  skip_before_action :extract_user, only: :lastevents_public
  skip_before_action :require_login, only: :lastevents_public

  # POST, GET /public/lastevents
  # GET /lastevents
  def lastevents_public
    lastevents
  end

  # POST /lastevents
  def lastevents
    path = http_request_path

    # map to a GET, so we can X-forward it
    volley_backend_path(path) unless forward_from_backend(path)
  end

  private

  def require_valid_project_name
    required_parameters :project
    raise InvalidProjectNameError, "invalid project name '#{params[:project]}'" unless Project.valid_name?(params[:project])
  end

  def set_issues_defaults
    @filter_changes = @states = nil
    @filter_changes = params[:changes].split(',') if params[:changes]
    @states = params[:states].split(',') if params[:states]
    @login = params[:login]
  end

  def set_target_project_name
    # FIXME: for OBS 3, api of branch and copy calls have target and source in the opposite place
    @target_project_name = if params[:cmd].in?(%w[branch fork release])
                             params[:target_project] # might be nil
                           else
                             params[:project]
                           end
  end

  def set_project
    @project = Project.find_by(name: params[:project])
    raise Project::Errors::UnknownObjectError, "Project not found: #{params[:project]}" unless @project
  end

  def set_target_package_name
    @target_package_name = params[:package]
    return unless params[:cmd].in?(%w[branch fork release])

    @target_package_name = params[:target_package] if params[:target_package]
  end

  def actually_create_incident(project)
    raise ModifyProjectNoPermission, "no permission to modify project '#{project.name}'" unless User.session.can_modify?(project)

    incident = MaintenanceIncident.build_maintenance_incident(project, no_access: params[:noaccess].present?)

    if incident
      render_ok data: { targetproject: incident.project.name }
    else
      render_error status: 400, errorcode: 'incident_has_no_maintenance_project',
                   message: 'incident projects shall only create below maintenance projects'
    end
  end

  def _check_single_target!(source_repository, target_repository, filter_architecture)
    # checking write access and architectures
    raise UnknownRepository, 'Invalid source repository' unless source_repository
    raise UnknownRepository, 'Invalid target repository' unless target_repository
    raise CmdExecutionNoPermission, "no permission to write in project #{target_repository.project.name}" unless User.session.can_modify?(target_repository.project)

    source_repository.check_valid_release_target!(target_repository, filter_architecture)
  end

  def verify_release_targets!(pro, filter_architecture = nil)
    repo_matches = nil
    repo_bad_type = nil

    pro.repositories.each do |repo|
      next if params[:repository] && params[:repository] != repo.name

      if params[:targetproject] || params[:targetrepository]
        target_repository = Repository.find_by_project_and_name(params[:targetproject], params[:targetrepository])

        _check_single_target!(repo, target_repository, filter_architecture)

        repo_matches = true
      else
        repo.release_targets.each do |releasetarget|
          next unless releasetarget

          unless releasetarget.trigger.in?(%w[manual maintenance])
            repo_bad_type = true
            next
          end

          _check_single_target!(repo, releasetarget.target_repository, filter_architecture)

          repo_matches = true
        end
      end
    end
    raise NoMatchingReleaseTarget, 'Trigger is not set to manual in any repository' if repo_bad_type && !repo_matches

    raise NoMatchingReleaseTarget, 'No defined or matching release target' unless repo_matches
  end

  def obj_set_flag(obj)
    obj.transaction do
      begin
        if params[:product]
          obj.set_repository_by_product(params[:flag], params[:status], params[:product])
        else
          # first remove former flags of the same class
          obj.remove_flag(params[:flag], params[:repository], params[:arch])
          obj.add_flag(params[:flag], params[:status], params[:repository], params[:arch])
        end
      rescue ArgumentError => e
        raise InvalidFlag, e.message
      end

      obj.store
    end
    render_ok
  end

  def obj_remove_flag(obj)
    obj.transaction do
      obj.remove_flag(params[:flag], params[:repository], params[:arch])
      obj.store
    end
    render_ok
  end

  def set_request_data
    @request_data = Xmlhash.parse(request.raw_post)
    return if @request_data

    render_error status: 400, errorcode: 'invalid_xml', message: 'Invalid XML'
  end

  def render_error_for_package_or_project(err_code, err_message, xml_obj, obj)
    render_error status: 400, errorcode: err_code, message: err_message if xml_obj && xml_obj != obj
  end

  def validate_xml_content(rdata_field, object, error_status, error_message)
    render_error_for_package_or_project(error_status,
                                        error_message,
                                        rdata_field,
                                        object)
  end
end
