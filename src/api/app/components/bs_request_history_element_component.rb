# This component renders a timeline of comments and request activity.
#
# It is used in the beta view of the request show page, under the Overview tab,
# merged with the BsRequestCommentComponent.
class BsRequestHistoryElementComponent < ApplicationComponent
  attr_reader :element

  def initialize(element:)
    super

    @element = element
  end
end
