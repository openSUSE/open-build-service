#  After some changes in Notification's database structure, some data needs to
#  be updated. But, instead of fixing the existing Notifications, we are going
#  to delete the affected ones and regenerate them with the correct values.
#
#  The deletion is made in a previous data migration. This one re-generates the
#  notifications.
#
#  Steps:

#  - Take all the existing BsRequests in state 'new' and create a RequestCreate
#    Notification for each of them.
#  - Take the BsRequests in state 'declined' that where created in the last 100 days and
#    create a RequestStatechange Notification for each of them.
#  - Take all the existing BsRequests in state 'review' with reviews in state 'new' and
#    create a ReviewWanted Notification for each of the reviews.
#  - Take the BsRequests created in the last 2 weeks and create a CommentForRequest
#    Notification for each comment on each BsRequest.

class RegenerateNotifications < ActiveRecord::Migration[5.2]
  def up
    create_request_create_notifications
    create_request_statechange_notifications
    create_review_wanted_notifications
    create_comment_for_request_notifications
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  # RequestCreated Notifications

  def create_request_create_notifications
    new_requests = BsRequest.where(state: :new)

    new_requests.each do |request|
      event = Event::RequestCreate.new(request.event_parameters)
      NotificationService::Notifier.new(event).call
    end
  end

  # RequestStatechange Notifications

  def create_request_statechange_notifications
    declined_requests = BsRequest.where(state: :declined).where(created_at: 100.days.ago.midnight..)

    declined_requests.each do |request|
      event = Event::RequestStatechange.new(request.event_parameters)
      event.payload['oldstate'] = request_old_state(request)
      NotificationService::Notifier.new(event).call
    end
  end

  def request_old_state(request)
    # Check history elements to guess the previous state
    # assuming the last one is always HistoryElement::RequestDeclined
    previous_history_element, last_history_element = request.history_elements.last(2)

    case previous_history_element.try(:type)
    when nil, 'HistoryElement::RequestAllReviewsApproved'
      'new'
    when 'HistoryElement::RequestDeclined'
      'declined'
    when 'HistoryElement::RequestReopened'
      return 'review' if request.reviews.find_by(state: :new).present?

      'new' # when no reviews or all of them were accepted
    when 'HistoryElement::ReviewAccepted'
      return 'declined' if last_history_element.description == 'Declined via staging workflow.'

      'review'
    else
      # when 'HistoryElement::RequestReviewAdded', 'HistoryElement::ReviewDeclined'
      # also for any other case that was overlooked (less accurate result)
      'review'
    end
  end

  # ReviewWanted Notifications

  def create_review_wanted_notifications
    new_reviews = Review.where(state: 'new').joins(:bs_request).where('bs_requests.state' => 'review')

    new_reviews.each do |review|
      params = review.event_parameters(review.bs_request.event_parameters)
      event = Event::ReviewWanted.new(params)
      NotificationService::Notifier.new(event).call
    end
  end

  # CommentForRequest Notifications

  def create_comment_for_request_notifications
    recent_request_comments = Comment.where('commentable_type = ? AND created_at >= ?', 'BsRequest', 2.weeks.ago.midnight)

    recent_request_comments.each do |comment|
      event = Event::CommentForRequest.new(comment.event_parameters)
      NotificationService::Notifier.new(event).call
    end
  end
end
