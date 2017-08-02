module Feature
  module Repository
    # ObsRepository for active and inactive features based on YamlRepository having default values for each key in OBS
    #
    class ObsRepository < YamlRepository
      # Returns list of active features
      #
      # @return [Array<Symbol>] list of active features
      #
      def active_features
        if User.current && (User.current.is_staff? || User.current.is_admin?)
          data = read_file(@yaml_file_name).with_indifferent_access
          get_active_features(data, :beta)
        else
          super
        end
      end
    end
  end
end
