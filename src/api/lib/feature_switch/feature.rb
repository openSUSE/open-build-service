module Feature
  @perform_initial_refresh_for_user = true

  def self.active?(feature)
    return beta_or_rollout.include?(feature) if User.session && (User.session.in_beta? || User.session.in_rollout?)
    active_features.include?(feature)
  end

  def self.beta_or_rollout
    refresh_data

    result = Repository::ObsRepository::DEFAULTS.merge(@data.dig(:production, :features) || {})
    result.merge!(@data.dig(:beta, :features) || {}) if User.session.in_beta?
    result.merge!(@data.dig(:rollout, :features) || {}) if User.session.in_rollout?
    result.select { |key, active| key if active }.keys
  end

  def self.refresh_data
    return unless @auto_refresh || @perform_initial_refresh_for_user || (@next_refresh_after && Time.now > @next_refresh_after)

    @data = YAML.load_file("#{Rails.root}/config/feature.yml").deep_symbolize_keys
    @perform_initial_refresh_for_user = false
  end
  private_class_method :refresh_data
end
