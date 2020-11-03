module WorkerStatusService
  class JobsStatisticsFetcher
    attr_reader :worker_status

    class << self
      def call
        new.statistics
      end
    end

    def initialize
      @worker_status = Hash.from_xml(backend_worker_status)
    end

    def waiting
      @worker_status['workerstatus']['waiting']
    end

    def blocked
      @worker_status['workerstatus']['blocked']
    end

    def statistics
      { waiting: waiting, blocked: blocked }
    end

    private

    def backend_worker_status
      Rails.cache.read('workerstatus') || Backend::Api::BuildResults::Worker.status
    end
  end
end
