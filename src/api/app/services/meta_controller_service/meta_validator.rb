module MetaControllerService
  class MetaValidator
    attr_reader :project, :request_data, :errors

    def initialize(params = {})
      @project = params[:project]
      @request_data = params[:request_data]
      @errors = []
    end

    def call
      remove_repositories = @project.get_removed_repositories(@request_data)
      @errors << Project.check_repositories(remove_repositories)[:error]
      @errors << Project.validate_remote_permissions(@request_data)[:error]
      @errors << Project.validate_link_xml_attribute(@request_data, @project.name)[:error]
      begin
        @errors << Project.validate_maintenance_xml_attribute(@request_data)[:error]
      rescue Project::Errors::UnknownObjectError => e
        @errors << "Maintained project not found: '#{e.message}'"
      end
      @errors << Project.validate_repository_xml_attribute(@request_data, @project.name)[:error]
      @errors.compact!
    end

    def valid?
      @errors.empty?
    end
  end
end
