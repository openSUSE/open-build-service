class WriteAndPreviewComponent < ApplicationComponent
  attr_reader :form, :preview_message_url

  def initialize(form, preview_message_url)
    super

    @form = form
    @preview_message_url = preview_message_url
  end
end
