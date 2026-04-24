module NotificationReasonable
  EVENT_TYPE_LABELS = {
    'Event::BuildFail' => 'Build Failure',
    'Event::ServiceFail' => 'Service Failure',
    'Event::ReviewWanted' => 'Review Wanted',
    'Event::RequestCreate' => 'Request Created',
    'Event::RequestStatechange' => 'Request State Change',
    'Event::CommentForProject' => 'Comment on Project',
    'Event::CommentForPackage' => 'Comment on Package',
    'Event::CommentForRequest' => 'Comment on Request',
    'Event::CommentForReport' => 'Comment on Report',
    'Event::RelationshipCreate' => 'Relationship Created',
    'Event::RelationshipDelete' => 'Relationship Deleted',
    'Event::ReportForProject' => 'Report for Project',
    'Event::ReportForPackage' => 'Report for Package',
    'Event::ReportForUser' => 'Report for User',
    'Event::ReportForComment' => 'Report for Comment',
    'Event::ReportForRequest' => 'Report for Request',
    'Event::ClearedDecision' => 'Cleared Decision',
    'Event::FavoredDecision' => 'Favored Decision',
    'Event::AppealCreated' => 'Appeal Created',
    'Event::WorkflowRunFail' => 'Workflow Run Failed',
    'Event::AddedUserToGroup' => 'Added to Group',
    'Event::RemovedUserFromGroup' => 'Removed from Group',
    'Event::Assignment' => 'Assignment',
    'Event::UpstreamPackageVersionChanged' => 'Upstream Version Change',
    'Event::GlobalRoleAssigned' => 'Global Role Assigned'
  }.freeze

  # Roles that relate to a specific package (project + package in payload)
  PACKAGE_ROLES = %w[maintainer bugowner reader package_watcher assignee
                     develpackage_or_package_maintainer].freeze
  # Roles that relate to a project only
  PROJECT_ROLES = %w[project_watcher].freeze
  # Roles that relate to the source side of a request action
  SOURCE_PACKAGE_ROLES = %w[source_maintainer source_package_watcher].freeze
  SOURCE_PROJECT_ROLES = %w[source_project_watcher].freeze
  # Roles that relate to the target side of a request action
  TARGET_PACKAGE_ROLES = %w[target_maintainer target_package_watcher].freeze
  TARGET_PROJECT_ROLES = %w[target_project_watcher].freeze
  # Roles that relate to a request
  REQUEST_ROLES = %w[reviewer creator request_watcher commenter].freeze

  def build_subscription_reason_text(event_type:, receiver_role:, event_payload:)
    role_label = EventSubscription::RECEIVER_ROLE_TEXTS[receiver_role.to_sym] || receiver_role
    event_label = EVENT_TYPE_LABELS[event_type] || event_type.to_s.gsub('Event::', '').titleize
    object_context = reason_object_context_from_payload(receiver_role.to_s, event_payload)

    "You received this because you subscribed to #{event_label} events as #{role_label}#{object_context}."
  end

  def reason_object_context_from_payload(role, payload)
    role = role.to_s
    if PACKAGE_ROLES.include?(role)
      project = payload['project']
      package = payload['package']
      if project && package
        " of package #{project}/#{package}"
      elsif project
        " of project #{project}"
      end
    elsif PROJECT_ROLES.include?(role)
      project = payload['project']
      " of project #{project}" if project
    elsif SOURCE_PACKAGE_ROLES.include?(role)
      project = payload['sourceproject']
      package = payload['sourcepackage']
      if project && package
        " of source package #{project}/#{package}"
      elsif project
        " of source project #{project}"
      end
    elsif SOURCE_PROJECT_ROLES.include?(role)
      project = payload['sourceproject']
      " of source project #{project}" if project
    elsif TARGET_PACKAGE_ROLES.include?(role)
      project = payload['targetproject']
      package = payload['targetpackage']
      if project && package
        " of target package #{project}/#{package}"
      elsif project
        " of target project #{project}"
      end
    elsif TARGET_PROJECT_ROLES.include?(role)
      project = payload['targetproject']
      " of target project #{project}" if project
    elsif REQUEST_ROLES.include?(role)
      number = payload['number']
      " on request ##{number}" if number
    end || ''
  end
end
