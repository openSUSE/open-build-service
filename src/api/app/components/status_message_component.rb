class StatusMessageComponent < ApplicationComponent
  def initialize(status_message:)
    super
    @status_message = status_message
  end
end
