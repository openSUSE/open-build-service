module CommitEvent

  def self.included(base)
    base.class_eval do
      payload_keys :involved_users, :commenter, :comment
    end
  end

  def expanded_payload
    p = payload.dup
    p['commenter'] = User.find(p['commenter'])
    p
  end

  def originator
    User.find(payload['commenter']).email
  end

end

class Event::CommentForProject < ::Event::Project
  include CommitEvent
  self.description = 'New comment for project created.'

  def subject
    "New comment in project #{payload['project']} by #{User.find(payload['commenter']).login}"
  end

end

class Event::CommentForPackage < ::Event::Package
  include CommitEvent

  self.description = 'New comment for package created.'

  def subject
    "New comment in package #{payload['project']}/#{payload['package']} by #{User.find(payload['commenter']).login}"
  end

end

class Event::CommentForRequest < ::Event::Base

  include CommitEvent
  self.description = 'New comment for request created.'
  payload_keys :request_id

  def subject
    "New comment in request #{payload['request_id']} by #{User.find(payload['commenter']).login}"
  end

  def subscribers
    req = BsRequest.find(payload['request_id'])
    subs = super
    subs << User.find_by_login(req.creator)
    subs.uniq
  end

end

