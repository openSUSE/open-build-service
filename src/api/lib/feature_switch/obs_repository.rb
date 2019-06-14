module Feature
  module Repository
    # ObsRepository for active and inactive features based on YamlRepository having default values for each key in OBS
    #
    class ObsRepository < YamlRepository
      # remember to update config/features.yml if changing
      DEFAULTS = {
        image_templates: true,
        cloud_upload: false,
        cloud_upload_azure: false,
        bootstrap: false,
        kiwi_image_editor: false
      }.with_indifferent_access

      attr_accessor :use_beta_features

      # Extracts active features from given hash
      #
      # @param data [Hash] hash parsed from yaml file
      # @param selector [String] uses the value for this key as source of feature data
      #
      def get_active_features(data, selector)
        data[selector] ||= {}
        features = data[selector].fetch('features', {})
        if use_beta_features && data.dig('beta', 'features')
          features.merge!(data['beta']['features'])
        end
        data[selector]['features'] = DEFAULTS.merge(features)
        super
      end
    end
  end
end
