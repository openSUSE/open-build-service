# This component renders the request description based on the type of the actions

class BsRequestDescriptionComponent < ApplicationComponent
  attr_reader :bs_request, :types

  def initialize(bs_request:)
    super()
    @bs_request = bs_request
    @types = bs_request.bs_request_actions.group_by(&:type)
  end

  def multiple_types?
    types.many?
  end

  def any_types_has_many_multiple_actions?
    types.any? { |_type, actions| actions.count > 10 }
  end
end
