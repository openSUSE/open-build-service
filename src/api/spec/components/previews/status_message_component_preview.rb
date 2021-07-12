class StatusMessageComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/status_message_component/as_anonymous_user
  def as_anonymous_user
    render(StatusMessageComponent.new(status_message: StatusMessage.first))
  end

  # Preview at http://HOST:PORT/rails/view_components/status_message_component/as_admin_user
  def as_admin_user
    # TODO: run_as doesn't change anything somehow... it's still the anonymous user in the session when rendering the view component (so the delete icon is not displayed)
    User.admins.first.run_as do
      render(StatusMessageComponent.new(status_message: StatusMessage.first))
    end
  end
end
