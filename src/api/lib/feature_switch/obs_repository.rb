# frozen_string_literal: true
module Feature
  module Repository
    # ObsRepository for active and inactive features based on YamlRepository having default values for each key in OBS
    #
    class ObsRepository < YamlRepository
      DEFAULTS = {
        image_templates: true,
        cloud_upload:    false
      }.freeze

      # Returns list of active features
      #
      # @return [Array<Symbol>] list of active features
      #
      def active_features
        data = read_file(@yaml_file_name).with_indifferent_access
        data[@environment]['features'] = DEFAULTS.merge(data[@environment]['features'])
        get_active_features(data, @environment)
      end
    end
  end
end
