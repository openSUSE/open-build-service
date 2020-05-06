module ConsistencyCheckJobService
  class BackendProjectImporter
    attr_reader :errors

    def initialize(project_name)
      @project = Project.new(name: project_name)
      @errors = []
    end

    def call
      create_project_frontend
    rescue APIError => e
      @errors << "Invalid project meta data hosted in src server for project #{@project}: #{e}"
    rescue ActiveRecord::RecordInvalid
      delete_source
      @errors << "DELETED #{@project} on backend due to invalid data"
    rescue Backend::NotFoundError
      @errors << "specified #{@project} does not exist on backend"
    end

    private

    def create_project_frontend
      @project.commit_opts = { no_backend_write: 1 }
      @project.update_from_xml!(Xmlhash.parse(meta))
      @project.save!
    end

    def meta
      Backend::Api::Sources::Project.meta(@project)
    end

    def delete_source
      Backend::Api::Sources::Project.delete(@project)
    end
  end
end
