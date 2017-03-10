module CommentEvent
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
    return [] unless payload['commenters']
    User.find(payload['commenters'])
  end
end

class Event::CommentForProject < ::Event::Project
  include CommentEvent
  receiver_roles :maintainer

  self.description = 'New comment for project created'

  def subject
    "New comment in project #{payload['project']} by #{User.find(payload['commenter']).login}"
  end
end

class Event::CommentForPackage < ::Event::Package
  include CommentEvent
  receiver_roles :maintainer

  self.description = 'New comment for package created'

  def subject
    "New comment in package #{payload['project']}/#{payload['package']} by #{User.find(payload['commenter']).login}"
  end
end

class Event::CommentForRequest < ::Event::Request
  include CommentEvent
  self.description = 'New comment for request created'
  payload_keys :request_number
  receiver_roles :source_maintainer, :target_maintainer, :creator, :reviewer

  def subject
    req = BsRequest.find_by_number(payload['number'])
    req_payload = req.notify_parameters
    "Request #{payload['number']} commented by #{User.find(payload['commenter']).login} (#{BsRequest.actions_summary(req_payload)})"
  end

  def set_payload(attribs, keys)
    # limit the error string
    attribs['comment'] = attribs['comment'][0..800] unless attribs['comment'].blank?
    attribs['files'] = attribs['files'][0..800] unless attribs['files'].blank?
    super(attribs, keys)
  end
end

# == Schema Information
#
# Table name: comments
#
#  id            :integer          not null, primary key
#  project_id    :integer
#  package_id    :integer
#  bs_request_id :integer
#  body          :text(65535)
#  parent_id     :integer
#  type          :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  user_id       :integer          not null
#
# Indexes
#
#  index_comments_on_bs_request_id  (bs_request_id)
#  index_comments_on_package_id     (package_id)
#  index_comments_on_project_id     (project_id)
#  parent_id                        (parent_id)
#  user_id                          (user_id)
#
