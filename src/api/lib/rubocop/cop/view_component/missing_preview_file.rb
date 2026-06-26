module RuboCop
  module Cop
    module ViewComponent
      class MissingPreviewFile < RuboCop::Cop::Base
        include RuboCop::Cop::RangeHelp # for source_range

        def on_new_investigation
          super

          component_filename = File.basename(processed_source.file_path)

          # Only consider Ruby files, anything else is ignored, even Haml templates ending with `.html.haml.rb`
          return unless component_filename.end_with?('_component.rb')
          # The ApplicationComponent should not have a preview file
          return if component_filename == 'application_component.rb'

          preview_filename = component_filename.gsub(/\.rb$/, '_preview.rb')
          # Relative path from `Rails.root`, but we cannot use that method since it is not available inside a RuboCop cop
          preview_file_relative_path = "spec/components/previews/#{preview_filename}"
          preview_file = File.join(Dir.pwd, preview_file_relative_path)

          return if File.exist?(preview_file)

          add_offense(source_range(processed_source.buffer, 1, 0),
                      message: "This view component should have a preview file (`src/api/#{preview_file_relative_path}`)")
        end
      end
    end
  end
end
