module Webui
  module Projects
    class MetaController < WebuiController
      require_dependency 'opensuse/validator'
      before_action :set_project, only: [:show]
      before_action :set_project_by_name, only: [:update]
      before_action :validate_meta, only: [:update], unless: -> { !params[:meta] }
      after_action :verify_authorized, only: [:update]

      def show
        @meta = @project.render_xml
        switch_to_webui2
      end

      def update
        authorize @project, :update?
        errors = []
        errors = validate_request_and_set_error(errors)
        errors = run_update(errors) if errors.empty?
        status = if errors.empty?
                   flash.now[:success] = 'Config successfully saved!'
                   200
                 else
                   flash.now[:error] = errors.compact.join("\n")
                   400
                 end
        switch_to_webui2
        render layout: false, status: status, partial: "layouts/#{view_namespace}/flash", object: flash
      end

      private

      def validate_meta
        Suse::Validator.validate('project', params[:meta])
        @request_data = Xmlhash.parse(params[:meta])
      rescue Suse::ValidationError => exception
        flash.now[:error] = exception.message
        render layout: false, status: 400, partial: "layouts/#{view_namespace}/flash", object: flash
      end

      def view_namespace
        switch_to_webui2? ? 'webui2' : 'webui'
      end

      def validate_request_and_set_error(errors)
        remove_repositories = @project.get_removed_repositories(@request_data)
        errors << Project.check_repositories(remove_repositories)[:error]
        errors << Project.validate_remote_permissions(@request_data)[:error]
        errors << Project.validate_link_xml_attribute(@request_data, @project.name)[:error]
        errors << Project.validate_maintenance_xml_attribute(@request_data)[:error]
        errors << Project.validate_repository_xml_attribute(@request_data, @project.name)[:error]
        errors.compact
      end

      def run_update(errors)
        Project.transaction do
          errors << @project.update_from_xml(@request_data)[:error]
          errors = errors.compact
          @project.store if errors.empty?
        end
        errors.compact
      end

      def set_project_by_name
        @project = Project.get_by_name(params[:project])
      rescue Project::UnknownObjectError
        @project = nil
      end
    end
  end
end
