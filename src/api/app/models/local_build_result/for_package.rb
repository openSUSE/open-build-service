class LocalBuildResult
  class ForPackage
    include ActiveModel::Model

    attr_accessor :package, :project, :show_all, :lastbuild, :view
    attr_reader :excluded_counter, :results

    def initialize(attributes = {})
      super
      self.view ||= 'status'
      buildresults
    end

    private

    attr_writer :excluded_counter, :results

    def buildresults
      self.results = {}
      self.excluded_counter = 0

      base_package_name = package.name
      backend_build_result.each do |result|
        has_flavor_for_base = false
        has_base_package_entry = false

        result.elements('status').each do |status|
          results[status['package']] ||= []
          has_flavor_for_base = true if status['package'].start_with?("#{base_package_name}:")
          has_base_package_entry = true if status['package'] == base_package_name

          if excluded_or_disabled?(status['code'])
            self.excluded_counter += 1
            next
          end
          results[status['package']] << local_build_result(result, status)
        end

        # When buildemptyflavor=false, the backend omits the base package entry.
        # Show the base package as "excluded" so the user is aware of this.
        next unless has_flavor_for_base && !has_base_package_entry

        results[base_package_name] ||= []
        if !show_all
          self.excluded_counter += 1
        else
          results[base_package_name] << local_build_result(result, { 'code' => 'excluded', 'details' => nil })
        end
      end
    end

    def local_build_result(result, status)
      result['info'] ||= {}
      buildtype = [result['info']].flatten.first['buildtype']
      LocalBuildResult.new(repository: result['repository'], is_repository_in_db: repository_in_db?(result['repository'], result['arch']),
                           architecture: result['arch'], code: status['code'], state: result['state'], details: status['details'],
                           buildtype: buildtype)
    end

    def repository_in_db?(repository, architecture)
      set_architectures_for unless @architectures_for
      architectures = @architectures_for[repository] || []
      architectures.include?(architecture)
    end

    def set_architectures_for
      repos_archs = project.repositories.joins(:architectures).pluck(:name, 'architectures.name')
      @architectures_for = {}
      repos_archs.each do |element|
        @architectures_for[element.first] ||= []
        @architectures_for[element.first] << element.second
      end
    end

    def excluded_or_disabled?(status)
      return false if show_all

      %w[excluded disabled].include?(status)
    end

    def backend_build_result
      backend_results = Buildresult.find_hashed(project: project, package: package, view: view, multibuild: '1', locallink: '1', lastbuild: lastbuild ? '1' : '0')
      backend_results.elements('result').sort_by { |a| a['repository'] }
    end
  end
end
