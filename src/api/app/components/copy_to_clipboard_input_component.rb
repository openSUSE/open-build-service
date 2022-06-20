class CopyToClipboardInputComponent < ApplicationComponent
  def initialize(input_text:, input_id: 'copy-to-clipboard')
    super
    @input_text = input_text
    @input_id = input_id
    @readonly_input_id = "#{input_id}-readonly"
  end
end
