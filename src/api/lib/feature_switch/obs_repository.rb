module Feature
  module Repository
    # ObsRepository for active and inactive features based on YamlRepository having default values for each key in OBS
    #
    class ObsRepository < YamlRepository
      DEFAULTS = {
        image_templates: true,
        cloud_upload:    false
      }.freeze

      # Read given file, perform erb evaluation and yaml parsing
      #
      # @param file_name [String] the file name fo the yaml config
      # @return [Hash]
      #
      def read_file(file_name)
        super.with_indifferent_access
      end

      # Extracts active features from given hash
      #
      # @param data [Hash] hash parsed from yaml file
      # @param selector [String] uses the value for this key as source of feature data
      #
      def get_active_features(data, selector)
        data[@environment]['features'] = DEFAULTS.merge(data[@environment]['features'])
        super
      end
    end
  end
end
