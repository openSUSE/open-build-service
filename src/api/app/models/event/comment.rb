require_dependency 'event/package'
require_dependency 'event/project'

class Event::CommentForProject < ::Event::Project
  self.raw_type = 'PROJECT_COMMENT_ADDED'
  self.description = 'New comment for project created.'
  payload_keys :involved_users, :commenter, :comment
end

class Event::CommentForPackage < ::Event::Package
  self.raw_type = 'PACKAGE_COMMENT_ADDED'
  self.description = 'New comment for package created.'
  payload_keys :involved_users, :commenter, :comment
end

class Event::CommentForRequest < ::Event::Base
  self.raw_type = 'REQUEST_COMMENT_ADDED'
  self.description = 'New comment for request created.'
  payload_keys :involved_users, :commenter, :request_id, :comment
end

