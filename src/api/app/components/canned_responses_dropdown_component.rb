class CannedResponsesDropdownComponent < ApplicationComponent
  def initialize(canned_responses)
    super

    @canned_responses = canned_responses
  end
end
