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

  private

  def icon
    case @element.type.demodulize
    when 'ReviewAccepted', 'RequestAccepted'
      tag.i(nil, class: 'fas fa-check text-success')
    when 'ReviewDeclined', 'RequestDeclined'
      tag.i(nil, class: 'fas fa-times text-danger')
    when 'RequestReviewAdded'
      tag.i(nil, class: 'fas fa-2xs fa-circle text-warning')
    else
      tag.i(nil, class: 'fas fa-code-commit text-dark')
    end
  end
end
