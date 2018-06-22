module ObsFactory

  # View decorator for a Project
  class ObsProjectPresenter < BasePresenter


    def build_and_failed_params
      params = { project: self.name, defaults: 0 }
      Buildresult.avail_status_values.each do |s|
        next if %w(succeeded excluded disabled).include? s.to_s
        params[s] = 1
      end

      self.repos.each do |r|
        next if exclusive_repository && r != exclusive_repository
        params["repo_#{r}"] = 1
      end
      # hard code the archs we care for
      params['arch_i586'] = 1
      params['arch_x86_64'] = 1
      params['arch_ppc64le'] = 1
      params['arch_local'] = 1
      params
    end


    def summary
      return @summary if @summary
      building = false
      failed = 0
      final = 0
      total = 0

      # first calculate the building state - and filter the results
      results = []
      build_summary.elements('result') do |result|
        next if exclusive_repository && result['repository'] != exclusive_repository
        if !%w(published unpublished unknown).include?(result['state']) || result['dirty'] == 'true'
          building = true
        end
        results << result
      end
      results.each do |result|
        result['summary'].elements('statuscount') do |sc|
          code = sc['code']
          count = sc['count'].to_i
          next if code == 'excluded' # plain ignore
          total += count
          if code == 'unresolvable'
            unless building # only count if finished
              failed += count
            end
            next
          end
          if %w(broken failed).include?(code)
            failed += count
          elsif %w(succeeded disabled).include?(code)
            final += count
          end
        end
      end
      if failed > 0
        failed = build_failures_count
      end
      if building
        build_progress = (100 * (final + failed)) / total
        build_progress = [99, build_progress].min
        if failed > 0
          @summary = [:building, "#{self.nickname}: #{build_progress}% (#{failed} errors)"]
        else
          @summary = [:building, "#{self.nickname}: #{build_progress}%"]
        end
      elsif failed > 0
        # don't duplicate packages in archs, so redo
        @summary = [:failed, "#{self.nickname}: #{failed} errors"]
      else
        @summary = [:succeeded, "#{self.nickname}: DONE"]
      end
    end
  end
end
