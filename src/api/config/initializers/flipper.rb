# It's completely fine to have rolled out feature toggles in this constant, since we need them in the development
# environment and review apps to test changes for those features. Rolled-out feature toggles aren't displayed anyway
# to users in the web UI for beta features.
ENABLED_FEATURE_TOGGLES = [
  { name: :request_show_redesign, description: 'Redesign of the request pages to improve the collaboration workflow' },
  { name: :content_moderation, description: 'Reporting inappropriate content' },
  { name: :color_themes, description: 'Color themes' },
  { name: :foster_collaboration, description: 'Features improving the collaboration opportunities between users of the build service.' },
  { name: :labels, description: 'Allow to apply labels to packages, submit requests and projects to improve collaboration between build service users.' },
  { name: :request_index, description: 'Redesign of listing requests' },
  { name: :canned_responses, description: 'Create messages using templates' }
].freeze

Flipper.configure do
  # Register beta and rollout groups by default.
  # We need to add it when initializing because Flipper.register doesn't
  # store anything in database.

  Flipper.register(:staff) do |user|
    user.respond_to?(:staff?) && user.staff?
  end

  Flipper.register(:beta) do |user|
    user.respond_to?(:in_beta?) && user.in_beta?
  end

  Flipper.register(:rollout) do |user|
    user.respond_to?(:in_rollout?) && user.in_rollout?
  end

  ENABLED_FEATURE_TOGGLES.each do |feature_toggle|
    feature_toggle_name = feature_toggle[:name]
    # Register a group for this feature toggle
    Flipper.register(feature_toggle_name) do |user|
      # The user has to be in beta for this group to be active
      user.respond_to?(:in_beta?) && user.in_beta? &&
        # If a user didn't disable the feature, the feature will be active
        user.respond_to?(:disabled_beta_features) && !user.disabled_beta_features.exists?(name: feature_toggle_name)
    end
  end
end
