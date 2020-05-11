module Staging
  class StagingController < ApplicationController
    private

    def set_project
      @project = Project.get_by_name(params[:staging_workflow_project])
    rescue Project::UnknownObjectError
      render_error(
        status: 404,
        errorcode: 'not_found',
        message: "Project '#{params[:staging_workflow_project]}' not found."
      )
    end

    def set_staging_workflow
      @staging_workflow = @project.staging
      return if @staging_workflow

      render_error(
        status: 404,
        errorcode: 'not_found',
        message: "Project #{@project} doesn't have an asociated Staging Workflow"
      )
    end

    def set_xml_hash
      request_body = request.body.read
      @parsed_xml = (Xmlhash.parse(request_body) || {}).with_indifferent_access if request_body.present?
      return if @parsed_xml.present?

      error_options = if request_body.present?
                        { status: 400, errorcode: 'invalid_xml_format', message: 'XML format is not valid' }
                      else
                        { status: 400, errorcode: 'invalid_request', message: 'Empty body' }
                      end
      render_error(error_options)
    end
  end
end
