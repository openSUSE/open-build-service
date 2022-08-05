# This component renders a timeline of comments and request activity.
#
# It is used in the beta view of the request show page, under the Overview tab,
# It merges the BsRequestCommentComponent and the BsRequestHistoryElement to
# provide a merged timeline of events.
class BsRequestActivityTimelineComponent < ApplicationComponent
  attr_reader :bs_request, :creator, :timeline

  def initialize(bs_request:)
    super
    @bs_request = bs_request
    @creator = User.find_by_login(bs_request.creator) || User.nobody

    # IDEA: Forge the first item to remove the need of having the hand-crafted "created request" haml fragment
    @timeline = (
      @bs_request.comments.without_parent.includes(:user) +
      @bs_request.history_elements.includes(:user)
    ).compact.sort_by(&:created_at)
  end
end
