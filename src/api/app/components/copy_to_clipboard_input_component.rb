class CopyToClipboardInputComponent < ApplicationComponent
  def initialize(input_text:)
    super
    @input_text = input_text
  end
end
