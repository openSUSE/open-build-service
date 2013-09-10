require 'event'

class Comment < ActiveRecord::Base
  belongs_to :project
  belongs_to :package
  belongs_to :bs_request

  after_create :create_notification_for_add_comments

  def self.save(params)
    @comment = {}
  	@comment['title'] 	= params[:title]
  	@comment['body'] = params[:body]
  	@comment['user'] = params[:user]
  	@comment['parent_id'] = params[:parent_id] if params[:parent_id]
  end

  def self.remove(params)
    if params[:id]
      comment = CommentRequest.new
    elsif params[:package]
      comment = CommentPackage.new
    else
      comment = CommentProject.new
    end

    comment.create_notifications_for_deleted_comments(params)
    self.update(params[:comment_id], :title => "This comment has been deleted", :body => "", :user => "_nobody_")
  end

  def create_notification_for_add_comments(params = {})
    params[:commenter] = self.user
    params[:comment] = self.body
  end

  # build an array of users, commenting on a specific object type
  def involved_users(object_field , object_value)
    record = Comment.where(object_field => object_value)
    users = []
    record.each do |comment|
      users << comment.user
    end
    users.uniq!
  end

  def self.destroy(params)
    if params[:id]
      comment = CommentRequest.new
    elsif params[:package]
      comment = CommentPackage.new
    else
      comment = CommentProject.new
    end

    comment.create_notifications_for_deleted_comments(params)
    Comment.find(params[:comment_id]).destroy
  end
end
