module ConsistencyCheckJobService
  class ProjectConsistencyChecker < BaseConsistencyChecker
    def list_frontend
      Project.order(:name).pluck(:name)
    end

    def list_backend
      dir_to_array(Xmlhash.parse(Backend::Api::Sources::Project.list))
    rescue Backend::NotFoundError
      # project disappeared ... may happen in running system
      []
    end
  end
end
