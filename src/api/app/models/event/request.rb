class Event::Request < ::Event::Base
  self.description = 'Request was updated'
  self.abstract_class = true
  payload_keys :author, :comment, :description, :id, :actions, :state, :when, :who
end

class Event::RequestAccepted < Event::Request
  self.raw_type = 'SRCSRV_REQUEST_ACCEPTED'
  self.description = 'Request was accepted'
  payload_keys :oldstate
end

class Event::RequestChange < Event::Request
  self.raw_type = "SRCSRV_REQUEST_CHANGE"
  self.description = 'Request XML was updated (admin only)'
end

class Event::RequestCreate < Event::Request
  self.raw_type = "SRCSRV_REQUEST_CREATE"
  self.description = 'Request created'
end

class Event::RequestDeclined < Event::Request
  self.raw_type = 'SRCSRV_REQUEST_DECLINED'
  self.description = 'Request declined'
  payload_keys :oldstate
end

class Event::RequestDelete < Event::Request
  self.raw_type = "SRCSRV_REQUEST_DELETE"
  self.description = 'Request was deleted (admin only)'
end

class Event::RequestReviewerAdded < Event::Request
  self.raw_type = "SRCSRV_REQUEST_REVIEWER_ADDED"
  self.description = 'Reviewer was added to a request'
  payload_keys :newreviewer
end

class Event::RequestReviewerGroupAdded < Event::Request
  self.raw_type = "SRCSRV_REQUEST_REVIEWER_GROUP_ADDED"
  self.description = 'Review for a group was added to a request'
  payload_keys :newreviewer_group
end

class Event::RequestReviewerPackageAdded < Event::Request
  self.raw_type = "SRCSRV_REQUEST_REVIEWER_PACKAGE_ADDED"
  self.description = 'Review for package maintainers added to a request'
  payload_keys :newreviewer_project, :newreviewer_package
end

class Event::RequestReviewerProjectAdded < Event::Request
  self.raw_type = "SRCSRV_REQUEST_REVIEWER_PROJECT_ADDED"
  self.description = 'Review for project maintainers added to a request'
  payload_keys :newreviewer_project
end

class Event::RequestRevoked < Event::Request
  self.raw_type = 'SRCSRV_REQUEST_REVOKED'
  self.description = 'Request was revoked'
  payload_keys :oldstate
end

class Event::RequestStatechange < Event::Request
  self.raw_type = 'SRCSRV_REQUEST_STATECHANGE'
  self.description = 'Request state was changed'
  payload_keys :oldstate
end

class Event::ReviewAccepted < Event::Request
  self.raw_type = 'SRCSRV_REVIEW_ACCEPTED'
  self.description = 'Request was accepted'
end

class Event::ReviewDeclined < Event::Request
  self.raw_type = 'SRCSRV_REVIEW_DECLINED'
  self.description = 'Request was declined'
end
