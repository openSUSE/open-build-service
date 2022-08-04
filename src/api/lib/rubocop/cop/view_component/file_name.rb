module RuboCop
  module Cop
    module ViewComponent
      class FileName < RuboCop::Cop::Base
        include RuboCop::Cop::RangeHelp # for source_range

        def on_new_investigation
          super

          file_path = File.basename(processed_source.file_path)

          return if file_path.end_with?('_component.rb')

          add_offense(source_range(processed_source.buffer, 1, 0),
                      message: "The name of the source file (`#{file_path}`) should end with `_component.rb`")
        end
      end
    end
  end
end
