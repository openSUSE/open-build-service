# This component renders a timeline of comments and request activity.
#
# It is used in the beta view of the request show page, under the Overview tab,
# merged with the BsRequestCommentComponent.
class BsRequestHistoryElementComponent < ApplicationComponent
  attr_reader :element, :request_reviews_for_non_staging_projects

  def initialize(element:, request_reviews_for_non_staging_projects: [])
    super()

    @element = element
    @request_reviews_for_non_staging_projects = request_reviews_for_non_staging_projects
  end

  private

  def icon
    case @element.type.demodulize
    when 'ReviewAccepted', 'RequestAccepted'
      tag.i(nil, class: 'fas fa-lg fa-check')
    when 'ReviewDeclined', 'RequestDeclined'
      tag.i(nil, class: 'fas fa-lg fa-times')
    when 'RequestReviewAdded'
      tag.i(nil, class: 'fas fa-sm fa-circle')
    else
      tag.i(nil, class: 'fas fa-lg fa-code-commit')
    end
  end

  def expand?
    case @element.type.demodulize
    when 'RequestReviewAdded', 'RequestPriorityChange', 'RequestDeleted', 'RequestSetIncident', 'RequestSuperseded', 'RequestAllReviewsApproved'
      false
    else
      true
    end
  end

  def pending_reviews?
    request_reviews_for_non_staging_projects.any?(&:new?)
  end
end
