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
