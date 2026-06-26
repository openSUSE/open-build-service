module EventMailerHelper
  def project_or_package_text(project, package)
    return "package #{project}/#{package}" if package.present?

    "project #{project}"
  end

  def event_relationship_recipient(event)
    # If the event is for a group, the recipient is the group. Otherwise, the recipient is simply referred to as 'you'.
    event.fetch('group', 'you')
  end
end
