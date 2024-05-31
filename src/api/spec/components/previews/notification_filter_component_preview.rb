class NotificationFilterComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_filter_component/preview
  def preview
    User.new.run_as do
      view_component = NotificationFilterComponent.new(notifications: User.session.notifications.for_web,
                                                       selected_filter: { kind: %w[comments build_failures], state: ['unread'] },
                                                       user: User.session)
      render(view_component)
    end
  end
end
