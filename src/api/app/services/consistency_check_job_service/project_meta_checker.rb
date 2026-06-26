module ConsistencyCheckJobService
  class ProjectMetaChecker
    attr_reader :errors

    def initialize(project)
      @project = project
      @errors = []
    end

    def call
      @errors << "Project meta is different in backend for #{@project.name}\n#{diff}" if diff.present?
    end

    private

    def diff
      hash_diff(frontend_meta, backend_meta)
    end

    def frontend_meta
      Xmlhash.parse(@project.to_axml)
    end

    def backend_meta
      Xmlhash.parse(Backend::Api::Sources::Project.meta(@project))
    rescue Backend::NotFoundError, Backend::Error
      Xmlhash::XMLHash.new
    end

    # transform hash to array, compare it and transform it back to hash
    def hash_diff(array_a, array_b)
      difference = array_a.size > array_b.size ? array_a.to_a - array_b.to_a : array_b.to_a - array_a.to_a
      Hash[*difference.flatten]
    end
  end
end
