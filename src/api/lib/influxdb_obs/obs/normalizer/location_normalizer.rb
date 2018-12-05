module InfluxDB
  module OBS
    module Normalizer
      class LocationNormalizer
        def initialize(kaller_locations = [])
          @kaller_locations = kaller_locations
        end

        def controller_name
          format_location(controller_location)
        end

        def backend_name
          format_location(backend_location)
        end

        private

        attr_reader :kaller_locations

        def format_location(location)
          return unless location

          file_path = location.absolute_path
          class_name = ::File.basename(file_path, ::File.extname(file_path)).classify
          "#{class_name}##{location.label}"
        end

        def backend_location
          @backend_location = kaller_locations.find { |call| call.absolute_path =~ /backend\/api/i }
        end

        def controller_location
          @controller_location = kaller_locations.find { |call| call.absolute_path =~ /app\/controllers/i }
        end
      end
    end
  end
end
