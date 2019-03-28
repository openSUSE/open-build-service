module Staging
  class StagingProjectCreator
    def initialize(request_body, staging_workflow)
      @request_body = request_body
      @staging_workflow = staging_workflow
    end

    def call
      if @request_body.blank?
        errors << 'Staging projects are empty'
        return self
      end
      staging_projects = Xmlhash.parse(@request_body).elements('staging_project').collect do |name|
        project = Project.find_or_initialize_by(name: name)
        project_validator = StagingProjectValidator.new(project).call

        unless project_validator.valid?
          errors << project_validator.errors
          next
        end

        project.staging_workflow_id = @staging_workflow.id
        project
      end
      staging_projects.each(&:store) if valid?
      self
    end

    def errors
      @errors ||= []
    end

    def valid?
      errors.empty?
    end

    private

    def staging_project_names
      [@staging_project_names].flatten
    end
  end
end
