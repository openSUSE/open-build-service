class CopyToClipboardInputComponent < ApplicationComponent
  def initialize(input_text:, html: {})
    super
    @input_text = input_text
    @html = html
  end
end
