class NotificationExcerptComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_excerpt_component/with_comment_notifiable
  def with_comment_notifiable
    notifiable = Comment.new(body: Faker::Lorem.paragraph_by_chars(number: 200))
    render(NotificationExcerptComponent.new(notifiable))
  end

  # Preview at http://HOST:PORT/rails/view_components/notification_excerpt_component/with_request_notifiable
  def with_request_notifiable
    notifiable = BsRequest.new(description: Faker::Lorem.paragraph_by_chars(number: 200))
    render(NotificationExcerptComponent.new(notifiable))
  end

  # Preview at http://HOST:PORT/rails/view_components/notification_excerpt_component/with_review_notifiable
  def with_review_notifiable
    notifiable = Review.new
    render(NotificationExcerptComponent.new(notifiable))
  end
end
