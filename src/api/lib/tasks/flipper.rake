namespace :flipper do
  desc 'Enable feature toggles from ENABLED_FEATURE_TOGGLES for their group'
  task enable_features_for_group: :environment do
    ENABLED_FEATURE_TOGGLES.each do |feature_toggle|
      feature_toggle_name = feature_toggle[:name]
      # Enable the feature toggle for group with the same name
      Flipper.enable(feature_toggle_name, feature_toggle_name)
    end
  end
end
