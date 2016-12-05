require 'event'
require 'set'

class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true # belongs to a Project, Package or BsRequest
  belongs_to :user, inverse_of: :comments

  validates :body, :commentable, :user, presence: true

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
    params[:commenters] = involved_users

    case commentable_type
    when "Package"
      params[:package] = commentable.name
      params[:project] = commentable.project.name
      # call the action
      Event::CommentForPackage.create params
    when "Project"
      params[:project] = commentable.name
      # call the action
      Event::CommentForProject.create params
    when "BsRequest"
      params = commentable.notify_parameters(params)
      # call the action
      Event::CommentForRequest.create params
    end
  end

  # build an array of users, commenting or being mentioned on the commentable of this comment
  def involved_users
    users = Set.new
    users_mentioned = Set.new
    Comment.where(commentable: commentable).find_each do |comment|
      # take the one making the comment
      users << comment.user_id
      # check if users are mentioned
      comment.body.split.each do |word|
        if /^@(?<user>.+)/ =~ word
          users_mentioned << user
        end
      end
    end
    users += User.where(login: users_mentioned.to_a).pluck(:id)
    users.to_a
  end

  def check_delete_permissions
    return false if User.current.blank?
    # Admins can always delete all comments
    return true if User.current.is_admin?

    # Users can always delete their own comments - or if the comments are deleted
    return true if User.current == user || user.is_nobody?

    case commentable_type
    when "Package"
      User.current.has_local_permission?('change_package', commentable)
    when "Project"
      User.current.has_local_permission?('change_project', commentable)
    when "BsRequest"
      commentable.is_target_maintainer?(User.current)
    end
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
end
