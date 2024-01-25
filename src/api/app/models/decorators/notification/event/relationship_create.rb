class Decorators::Notification::Event::RelationshipCreate < Decorators::Notification::Common
  def description_text
    role = notification.event_payload['role']
    user = notification.event_payload['who']
    recipient = notification.event_payload.fetch('group', 'you')
    project = notification.event_payload['project']
    package = notification.event_payload['package']
    target_object = [project, package].compact.join(' / ')
    "#{user} made #{recipient} #{role} of #{target_object}"
  end

  def notifiable_link_text(_helpers)
    role = notification.event_payload['role']
    if notification.event_payload['package']
      "Added as #{role} of a package"
    else
      "Added as #{role} of a project"
    end
  end

  def notifiable_link_path
    if notification.event_payload['package']
      Rails.application.routes.url_helpers.package_users_path(notification.event_payload['project'],
                                                              notification.event_payload['package'])
    else
      Rails.application.routes.url_helpers.project_users_path(notification.event_payload['project'])
    end
  end

  def avatar_objects
    [User.find_by(login: notification.event_payload['who'])]
  end
end
