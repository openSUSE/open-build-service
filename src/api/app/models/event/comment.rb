module CommentEvent
  def self.included(base)
    base.class_eval do
      payload_keys :commenters, :commenter, :comment_body, :comment_title
      receiver_roles :commenter
      shortenable_key :comment_body
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

  def custom_headers
    h = super
    h['X-OBS-Request-Commenter'] = originator.login
    h
  end
end

class Event::CommentForRequest < ::Event::Request
  include CommentEvent
  self.description = 'New comment for request created'
  payload_keys :request_number
  receiver_roles :source_maintainer, :target_maintainer, :creator, :reviewer, :source_watcher, :target_watcher
  after_create_commit :send_to_bus

  def self.message_bus_routing_key
    "#{Configuration.amqp_namespace}.request.comment"
  end

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
#  id               :integer          not null, primary key
#  body             :text(65535)
#  parent_id        :integer          indexed
#  created_at       :datetime
#  updated_at       :datetime
#  user_id          :integer          not null, indexed
#  commentable_type :string(255)      indexed => [commentable_id]
#  commentable_id   :integer          indexed => [commentable_type]
#
# Indexes
#
#  index_comments_on_commentable_type_and_commentable_id  (commentable_type,commentable_id)
#  parent_id                                              (parent_id)
#  user_id                                                (user_id)
#
# Foreign Keys
#
#  comments_ibfk_1  (user_id => users.id)
#  comments_ibfk_4  (parent_id => comments.id)
#
