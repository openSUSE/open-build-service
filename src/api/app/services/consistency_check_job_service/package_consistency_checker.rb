module ConsistencyCheckJobService
  class PackageConsistencyChecker < BaseConsistencyChecker
    def initialize(project)
      @project = project
      super
    end

    def list_frontend
      @project.packages.pluck(:name)
    end

    # filter multibuild source container
    def list_backend
      list_backend_packages.map { |e| e.start_with?('_patchinfo:', '_product:') ? e : e.gsub(/:.*$/, '') }
    end

    private

    def list_backend_packages
      dir_to_array(Xmlhash.parse(Backend::Api::Sources::Project.packages(@project.name)))
    # project disappeared ... may happen in running system
    rescue Backend::NotFoundError
      []
    end
  end
end
