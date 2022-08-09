namespace :flipper do
  desc 'Enable all feature toggles for the beta group'
  task enable_features_for_group: :environment do
    FEATURE_TOGGLES.each do |feature_toggle|
      feature_toggle_name = feature_toggle[:name]
      # Enable the feature toggle for group with the same name
      Flipper.enable(feature_toggle_name, :beta)
    end
  end
end
