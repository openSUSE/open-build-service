module WorkflowVersionMatcher
  # In case no version is specified in the workflow yaml, we fallback
  # to the current highest minor version, since we don't introduce
  # breaking changes with those
  FALLBACK_VERSION = '1.1'.freeze
  FEATURES_FOR_VERSION = { '1.1': ['event_aliases'] }.freeze

  def feature_available_for_workflow_version?(workflow_version:, feature_name:)
    workflow_version = FALLBACK_VERSION if workflow_version.blank?

    FEATURES_FOR_VERSION.each do |feature_version, features|
      return true if Gem::Version.new(workflow_version) >= Gem::Version.new(feature_version) && features.include?(feature_name)
    end
    false
  end
end
