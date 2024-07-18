class CannedResponsesDropdownComponent < ApplicationComponent
  def initialize(canned_responses)
    super

    @canned_responses = canned_responses
    @canned_responses_by_type = canned_responses_by_type
  end

  private

  def canned_responses_by_type
    # Only the types available in the user's canned responses
    types = @canned_responses.pluck(:decision_type).uniq

    types.index_with do |decision_type|
      @canned_responses.where(decision_type: decision_type)
    end
  end
end
