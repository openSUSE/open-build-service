class NotificationFilterComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/notification_filter_component/preview
  def preview
    User.new.run_as do
      view_component = NotificationFilterComponent.new(selected_filter: { type: 'comments' },
                                                       projects_for_filter: { OBS: 1 },
                                                       groups_for_filter: { heroes: 1 })
      view_component.instance_variable_set(:@count, { unread: 5, Comment: 2, BsRequest: 3, incoming_requests: 1, outgoing_requests: 4 })
      render(view_component)
    end
  end
end
