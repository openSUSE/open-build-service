# frozen_string_literal: true

module Feature
  @perform_initial_refresh_for_user = true

  def self.active?(feature)
    if User.current && (User.current.is_admin? || User.current.is_staff?)
      # caching the feature.yml file, this is basically taken from Feature.active_features
      if @auto_refresh || @perform_initial_refresh_for_user || (@next_refresh_after && Time.now > @next_refresh_after)
        @data = YAML.load_file("#{Rails.root}/config/feature.yml").with_indifferent_access
        @perform_initial_refresh_for_user = false
      end
      Repository::ObsRepository::DEFAULTS.merge(@data[Rails.env]['features']).with_indifferent_access.key?(feature)
    else
      active_features.include?(feature)
    end
  end
end
