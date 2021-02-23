module MonitorControllerService
  class BuildingInformationUpdater
    attr_accessor :workers

    def initialize
      @workers = {}
    end

    def call
      initialize_workers
      update_workers
      self
    end

    private

    def worker_status
      @worker_status ||= Xmlhash.parse(WorkerStatus.hidden.to_xml)
    end

    def initialize_workers
      @workers = worker_status.elements('idle').collect { |b| [worker_id(b), {}] }.to_h
    end

    def update_workers
      @workers.merge!(@worker_status.elements('building').collect { |b| [worker_id(b), workers_hash(b, calculate_delta(b['starttime'].to_i))] }.to_h)
    end

    def workers_hash(b, delta)
      b.slice('project', 'repository', 'package', 'arch', 'starttime').merge('delta' => delta.to_s)
    end

    def calculate_delta(starttime)
      delta = (Time.now - Time.at(starttime)).round
      delta = 5 if delta < 5
      delta = max_time if delta > max_time
      delta = (100 * Math.sin(Math.acos(1 - (Float(delta) / max_time)))).round
      delta = 100 if delta > 100
      delta
    end

    def worker_id(b)
      b['workerid'].gsub(%r{[:./]}, '_')
    end

    def max_time
      4.hours.to_i
    end
  end
end
