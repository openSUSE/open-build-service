class AddReviewCollapsibleComponent < ApplicationComponent
  attr_reader :bs_request

  def initialize(bs_request)
    super()

    @bs_request = bs_request
  end
end
