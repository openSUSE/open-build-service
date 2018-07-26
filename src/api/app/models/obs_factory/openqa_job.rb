module ObsFactory
  # Local representation of a job in the remote openQA. Uses a OpenqaApi (with a
  # hardcoded base url) to read the information and the Rails cache to store it
  class OpenqaJob
    include ActiveModel::Model
    extend ActiveModel::Naming
    include ActiveModel::Serializers::JSON

    attr_accessor :id, :name, :state, :result, :clone_id, :iso, :modules, :settings

    def self.openqa_base_url
      # build.opensuse.org can reach only the host directly, so we need
      # to use http - and accept a https redirect if used on work stations
      CONFIG['openqa_base_url'] || "http://openqa.opensuse.org"
    end

    def self.openqa_links_url
      CONFIG['openqa_links_url'] || "https://openqa.opensuse.org"
    end

    @@api = ObsFactory::OpenqaApi.new(openqa_base_url)

    # Reads jobs from the openQA instance or the cache with an interface similar
    # to ActiveRecord::Base#find_all_by
    #
    # If searching by iso or getting the full list, caching comes into play. In
    # any other case, a GET query to openQA is always performed.
    #
    # param [Hash] args filters to use in the query. Valid values:
    #              :build, :distri, :iso, :maxage, :state, :group and :version
    # param [Hash] opt Options:
    #   :cache == 'refresh' forces a refresh of the cache
    #   :exclude_modules skips the loading of the modules information (which
    #      needs an extra GET request per job). The #modules atribute will be
    #      empty for all the jobs (except those read from the cache) and the
    #      results will not be cached
    def self.find_all_by(args = {}, opt = {})
      refresh = (opt.symbolize_keys[:cache].to_s == 'refresh')
      exclude_mod = !!opt.symbolize_keys[:exclude_modules]
      filter = args.symbolize_keys.slice(:iso, :state, :build, :maxage, :distri, :version, :group)

      # We are only interested in current results
      get_params = {scope: 'current'}

      # If searching for the whole list of jobs, it caches the jobs
      # per ISO name.
      if filter.empty?
        Rails.cache.delete('openqa_isos') if refresh
        jobs = []
        isos = Rails.cache.read('openqa_isos')
        # If isos are in the cache, everything is read from cache
        if isos
          (isos + [nil]).each do |iso|
            jobs += Rails.cache.read("openqa_jobs_for_iso_#{iso}") || []
          end
        else
          # Get the bare list of jobs
          jobs = @@api.get('jobs', get_params)['jobs']
          # If exclude_mod is given, that's all. But if not...
          unless exclude_mod
            # First, enrich the result with the modules information and cache
            # the jobs per ISO
            jobs.group_by { |j| (j['assets']['iso'].first rescue nil) }.each do |iso, iso_jobs|
              Rails.cache.write("openqa_jobs_for_iso_#{iso}", iso_jobs, expires_in: 2.minutes)
            end
            # And then, cache the list of ISOs
            isos = jobs.map { |j| (j['assets']['iso'].first rescue nil) }.sort.compact.uniq
            Rails.cache.write('openqa_isos', isos, expires_in: 2.minutes)
          end
        end
      # If searching only by ISO, cache that one
      elsif filter.keys == [:iso]
        cache_entry = "openqa_jobs_for_iso_#{filter[:iso]}"
        Rails.cache.delete(cache_entry) if refresh
        jobs = Rails.cache.read(cache_entry)
        if jobs.nil?
          get_params[:iso] = filter[:iso]
          jobs = @@api.get('jobs', get_params)['jobs']
          unless exclude_mod
            Rails.cache.write(cache_entry, jobs, expires_in: 2.minutes)
          end
        end
      # In any other case, don't cache
      else
        get_params.merge!(filter)
        jobs = @@api.get('jobs', get_params)['jobs']
      end
      unless jobs.nil?
        jobs.map { |j| OpenqaJob.new(j.slice(*attributes)) }
      else
        return Hash.new
      end
    end

    # Name of the modules which failed during openQA execution
    #
    # @return [Array] array of module names
    def failing_modules
      modules.reject { |m| %w(passed softfailed running none).include? m['result'] }.map { |m| m['name'] }
    end

    # Result of the job, or its state if no result is available yet
    #
    # @return [String] state if result is 'none', value of result otherwise
    def result_or_state
      if result == 'none'
        state
      else
        result
      end
    end

    def self.attributes
      %w(id name state result clone_id iso modules settings)
    end

    # Required by ActiveModel::Serializers
    def attributes
      Hash[self.class.attributes.map { |a| [a, nil] }]
    end
  end
end
