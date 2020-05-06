module ConsistencyCheckJobService
  class BackendPackageImporter
    attr_reader :errors

    def initialize(project, package_name)
      @project = project
      @package = @project.packages.build(name: package_name)
      @errors = []
    end

    def call
      create_package_frontend
    rescue ActiveRecord::RecordInvalid,
           Backend::NotFoundError
      delete_package
      @errors << delete_error_message
    end

    private

    def delete_error_message
      "DELETED in backend due to invalid data #{@project.name}/#{@package.name}"
    end

    def create_package_frontend
      @package.commit_opts = { no_backend_write: 1 }
      @package.update_from_xml!(Xmlhash.parse(meta))
      @package.save!
    end

    def meta
      Backend::Api::Sources::Project.meta(@project)
    end

    def delete_package
      Backend::Api::Sources::Package.delete(@project.name, @package.name)
    end
  end
end
