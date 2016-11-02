require 'event'
require 'set'

class Comment < ApplicationRecord
  belongs_to :bs_request, inverse_of: :comments
  belongs_to :project, inverse_of: :comments
  belongs_to :package, inverse_of: :comments
  belongs_to :user, inverse_of: :comments

  validates :body, :user, :type, presence: true

  # Only instances of Comment's children can be created, not directly from Comment.
  # So the type attribute, which is reserved for storing the inheritance class, must be the name of a child class.
  validate :check_is_child

  after_create :create_notification

  has_many :children, dependent: :destroy, class_name: 'Comment', foreign_key: 'parent_id'

  extend ActsAsTree::TreeWalker
  acts_as_tree order: "created_at"

  def to_s
    body
  end

  def create_notification(params = {})
    params[:commenter] = user.id
    params[:comment_body] = body
  end

  # build an array of users, commenting on a specific object type
  def involved_users(object_field, object_value)
    record = Comment.where(object_field => object_value)
    users = Set.new
    users_mentioned = Set.new
    record.each do |comment|
      # take the one making the comment
      users << comment.user_id
      # check if users are mentioned
      comment.body.split.each do |word|
        if word =~ /^@/
          users_mentioned << word.gsub(%r{^@}, '')
        end
      end
    end
    users += User.where(login: users_mentioned.to_a).pluck(:id)
    users.to_a
  end

  def check_delete_permissions
    # Admins can always delete all comments
    return true if User.current.is_admin?

    # Users can always delete their own comments - or if the comments are deleted
    User.current == user || user.is_nobody?
  end

  def to_xml(builder)
    attrs = { who: user, when: created_at, id: id }
    attrs[:parent] = parent_id if parent_id

    builder.comment_(attrs) do
      builder.text(body)
    end
  end

  def blank_or_destroy
    if children.exists?
      self.body = 'This comment has been deleted'
      self.user = User.find_nobody!
      save!
    else
      destroy
    end
  end

  # FIXME: This is to work around https://github.com/rails/rails/pull/12450/files
  def destroy
    super
  end

  private

  def check_is_child
    if type && type.safe_constantize.try(:superclass) != Comment
      errors[:type] << "is reserved for storing the inheritance class which was not found"
    end
  end
end
