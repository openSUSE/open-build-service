class LocalBuildResult
  class ForPackage
    include ActiveModel::Model
    attr_accessor :package, :project, :show_all
    attr_reader :excluded_counter, :results

    def initialize(attributes = {})
      super
      buildresults
    end

    private

    attr_writer :excluded_counter, :results

    def buildresults
      self.results = {}
      self.excluded_counter = 0
      backend_build_result.each do |result|
        result.elements('status').each do |status|
          results[status['package']] ||= []
          if excluded?(status['code'])
            self.excluded_counter += 1
            next
          end
          results[status['package']] << local_build_result(result, status)
        end
      end
    end

    def local_build_result(result, status)
      LocalBuildResult.new(repository: result['repository'], architecture: result['arch'],
                           code: status['code'], state: result['state'], details: status['details'])
    end

    def excluded?(status)
      !show_all && status == 'excluded'
    end

    def backend_build_result
      backend_results = Buildresult.find_hashed(project: project, package: package, view: 'status', multibuild: '1', locallink: '1')
      backend_results.elements('result').sort_by { |a| a['repository'] }
    end
  end
end
