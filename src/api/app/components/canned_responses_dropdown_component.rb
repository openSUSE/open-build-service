class CannedResponsesDropdownComponent < ApplicationComponent
  def initialize(canned_responses)
    super

    @canned_responses = canned_responses
    @canned_responses_by_kind = canned_responses_by_kind
  end

  private

  def canned_responses_by_kind
    # Only the kinds available in the user's canned responses
    kinds = @canned_responses.pluck(:decision_kind).uniq

    kinds.index_with do |decision_kind|
      @canned_responses.where(decision_kind: decision_kind)
    end
  end
end
