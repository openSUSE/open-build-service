module CommitEvent

  def self.included(base)
    base.class_eval do
      payload_keys :commenters, :commenter, :comment_body, :comment_title
      receiver_roles :commenter
    end
  end

  def expanded_payload
    p = payload.dup
    p['commenter'] = User.find(p['commenter'])
    p
  end

  def originator
    User.find(payload['commenter'])
  end

  def commenters
    payload['commenters'] || []
  end
end

class Event::CommentForProject < ::Event::Project
  include CommitEvent
  receiver_roles :maintainer

  self.description = 'New comment for project created'

  def subject
    "New comment in project #{payload['project']} by #{User.find(payload['commenter']).login}: #{payload['comment_title']}"
  end

end

class Event::CommentForPackage < ::Event::Package
  include CommitEvent
  receiver_roles :maintainer

  self.description = 'New comment for package created'

  def subject
    "New comment in package #{payload['project']}/#{payload['package']} by #{User.find(payload['commenter']).login}: #{payload['comment_title']}"
  end

end

class Event::CommentForRequest < ::Event::Request

  include CommitEvent
  self.description = 'New comment for request created'
  payload_keys :request_id
  receiver_roles :target_maintainer, :creator, :reviewer

  def subject
    "New comment in request #{payload['id']} by #{User.find(payload['commenter']).login}: #{payload['comment_title']}"
  end

end

