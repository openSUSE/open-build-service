module ConsistencyCheckJobService
  class BaseConsistencyChecker
    def initialize(_project = nil)
      @diff_backend_frontend = []
      @diff_frontend_backend = []
    end

    def call
      # generate diffs
      diff_frontend_backend
      diff_backend_frontend
      self
    end

    def diff_frontend_backend
      @diff_frontend_backend ||= (list_frontend - list_backend)
    end

    def diff_backend_frontend
      @diff_backend_frontend ||= (list_backend - list_frontend)
    end

    def dir_to_array(xmlhash)
      xmlhash.elements('entry').pluck('name').sort
    end
  end
end
