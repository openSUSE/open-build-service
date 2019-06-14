module Feature
  def self.use_beta_features(enable)
    return if (@repository.use_beta_features || false) == enable
    @repository.use_beta_features = enable
    @perform_initial_refresh = true
  end
end
