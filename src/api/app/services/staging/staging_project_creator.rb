module Staging
  class StagingProjectCreator
    def initialize(staging_project_names, staging_workflow)
      @staging_project_names = staging_project_names
      @staging_workflow = staging_workflow
    end

    def call
      staging_projects = []
      staging_project_names.compact.each do |name|
        project = Project.find_or_initialize_by(name: name)
        project_validator = StagingProjectValidator.new(project).call

        if project_validator.valid?
          project.staging_workflow_id = @staging_workflow.id
          staging_projects << project
        else
          errors << project_validator.errors
        end
      end
      errors << 'Staging projects are empty' if staging_projects.empty?
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
