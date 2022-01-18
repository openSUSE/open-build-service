class CopyToClipboardInputComponent < ApplicationComponent
  def initialize(token_string:)
    super
    @token_string = token_string
  end
end
