module WorkerStatusService
  class WorkerStatisticsFetcher
    attr_reader :worker_status

    class << self
      def call
        new.statistics
      end
    end

    def initialize
      @worker_status = Nokogiri::XML(backend_worker_status)
    end

    def statistics
      { building: building, idle: idle, total: total }
    end

    def total
      building + idle
    end

    def building
      worker_status.search('//building').size
    end

    def idle
      worker_status.search('//idle').size
    end

    private

    def backend_worker_status
      Rails.cache.read('workerstatus') || Backend::Api::BuildResults::Worker.status
    end
  end
end
