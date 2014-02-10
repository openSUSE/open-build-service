require 'event'

class Comment < ActiveRecord::Base

  belongs_to :bs_request, inverse_of: :comments
  belongs_to :project, inverse_of: :comments
  belongs_to :package, inverse_of: :comments
  belongs_to :user, inverse_of: :comments

  validates :body, :user, :type, presence: true

  after_create :create_notification

  has_many :children, :class_name => 'Comment', :foreign_key => 'parent_id'

  def create_notification(params = {})
    params[:commenter] = self.user.id
    params[:comment_body] = self.body
  end

  # build an array of users, commenting on a specific object type
  def involved_users(object_field, object_value)
    record = Comment.where(object_field => object_value)
    users = []
    record.each do |comment|
      Rails.logger.debug "IU2 #{comment.inspect}"
      users << comment.user_id
    end
    users.uniq
  end

  def check_delete_permissions

    # Admins can always delete all comments
    if User.current.is_admin?
      return true
    end

    # Users can always delete their own comments - or if the comments are deleted
    User.current == self.user || self.user.is_nobody?
  end

  def to_xml(builder)
    attrs = { who: self.user, when: self.created_at, id: self.id }
    attrs[:parent] = self.parent_id if self.parent_id

    builder.comment_(attrs) do
      builder.text(self.body)
    end
  end

  def destroy
    if self.children.exists?
      self.body = 'This comment has been deleted'
      self.user = User.find_by_login '_nobody_'
      self.save!
    else
      super
    end
  end
end
