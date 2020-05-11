module LocalBuildStatistic
  class ForPackage
    include ActiveModel::Model
    attr_accessor :package, :project, :repository, :architecture
    attr_reader :results

    def initialize(attributes = {})
      super
      statistic
    end

    private

    attr_writer :results

    def statistic
      result = backend_statistics
      return if result.empty?

      disk = result.dig('disk', 'usage')
      memory = result.dig('memory', 'usage')
      times = result.get('times')
      local_statistics = LocalStatistic.new

      if disk
        local_statistics.disk = LocalBuildStatistic::Package::Disk.new(size: disk.dig('size', '_content'),
                                                                       unit: disk.dig('size', 'unit'),
                                                                       io_requests: disk['io_requests'],
                                                                       io_sectors: disk['io_sectors'])
      end
      if memory
        local_statistics.memory = LocalBuildStatistic::Package::Memory.new(size: memory.dig('size', '_content'),
                                                                           unit: memory.dig('size', 'unit'))
      end
      if times
        local_statistics.times = LocalBuildStatistic::Package::Time.new(total: times.dig('total', 'time', '_content'),
                                                                        total_unit: times.dig('total', 'time', 'unit'),
                                                                        install: times.dig('install', 'time', '_content'),
                                                                        install_unit: times.dig('install', 'time', 'unit'),
                                                                        preinstall: times.dig('preinstall', 'time', '_content'),
                                                                        preinstall_unit: times.dig('preinstall', 'time', 'unit'),
                                                                        main: times.dig('main', 'time', '_content'),
                                                                        main_unit: times.dig('main', 'time', 'unit'))
      end

      self.results = local_statistics
    end

    def backend_statistics
      Xmlhash.parse(Backend::Api::BuildResults::Status.statistics(project, package, repository, architecture))
    rescue Backend::Error
      return []
    end
  end
end
