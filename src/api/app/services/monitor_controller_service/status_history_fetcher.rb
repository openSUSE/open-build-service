module MonitorControllerService
  class StatusHistoryFetcher
    def initialize(key, range)
      @key = key
      @range = user_range(range)
    end

    def call
      Rails.cache.fetch(custom_cache_key, expires_in: (@range.to_i * 3600) / 150) do
        status_history
      end
    end

    private

    def user_range(range)
      [upper_range_limit, range].min
    end

    def upper_range_limit
      24 * 365
    end

    def custom_cache_key
      "#{@key}-#{@range}"
    end

    def status_history
      StatusHistory.history_by_key_and_hours(@key, @range).sort_by { |a| a[0] }
    end
  end
end
