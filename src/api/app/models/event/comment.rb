class Event::AddCommentForProject < ::Event::Project
  self.raw_type = 'PROJECT_COMMENT_ADDED'
  self.description = 'New comment for project created.'
  payload_keys :involved_users, :commenter, :comment
end

class Event::AddCommentForPackage < ::Event::Package
  self.raw_type = 'PACKAGE_COMMENT_ADDED'
  self.description = 'New comment for package created.'
  payload_keys :involved_users, :commenter, :comment
end

class Event::AddCommentForRequest < ::Event::Base
  self.raw_type = 'REQUEST_COMMENT_ADDED'
  self.description = 'New comment for request created.'
  payload_keys :involved_users, :commenter, :request_id, :comment
end

class Event::DeleteCommentForRequest < ::Event::Base
  self.raw_type = 'REQUEST_COMMENT_DELETE'
  self.description = 'Comment for request deleted.'
  payload_keys :involved_users, :commenter, :request_id, :comment
end

class Event::DeleteCommentForProject < ::Event::Project
  self.raw_type = 'PROJECT_COMMENT_DELETE'
  self.description = 'Comment for project deleted.'
  payload_keys :involved_users, :commenter, :comment
end

class Event::DeleteCommentForPackage < ::Event::Package
  self.raw_type = 'PACKAGE_COMMENT_DELETE'
  self.description = 'Comment for package deleted.'
  payload_keys :involved_users, :commenter, :comment
end