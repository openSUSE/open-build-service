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
          if excluded_or_disabled?(status['code'])
            self.excluded_counter += 1
            next
          end
          results[status['package']] << local_build_result(result, status)
        end
      end
    end

    def local_build_result(result, status)
      LocalBuildResult.new(repository: result['repository'], is_repository_in_db: repository_in_db?(result['repository'], result['arch']),
                           architecture: result['arch'], code: status['code'], state: result['state'], details: status['details'])
    end

    def repository_in_db?(repository, architecture)
      set_architectures_for unless @architectures_for
      architectures = @architectures_for[repository] || []
      architectures.include?(architecture)
    end

    def set_architectures_for
      repos_archs = project.repositories.joins(:architectures).pluck(:name, Arel.sql('architectures.name'))
      @architectures_for = {}
      repos_archs.each do |element|
        @architectures_for[element.first] ||= []
        @architectures_for[element.first] << element.second
      end
    end

    def excluded_or_disabled?(status)
      return false if show_all

      ['excluded', 'disabled'].include?(status)
    end

    def backend_build_result
      backend_results = Buildresult.find_hashed(project: project, package: package, view: 'status', multibuild: '1', locallink: '1')
      backend_results.elements('result').sort_by { |a| a['repository'] }
    end
  end
end
