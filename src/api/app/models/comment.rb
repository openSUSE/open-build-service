require 'event/comment'
class Comment < ActiveRecord::Base
  belongs_to :project
  belongs_to :package
  belongs_to :bs_request

  after_save :create_notification

  def self.save(params)
    @comment = {}
  	@comment['title'] 	= params[:title]
  	@comment['body'] = params[:body]
  	@comment['user'] = params[:user]
  	@comment['parent_id'] = params[:parent_id] if params[:parent_id]
  end

  def self.remove(params)
    self.update(params[:comment_id], :title => "This comment has been deleted", :body => "", :user => "_nobody_")
  end

  def create_notification(params = {})
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

end
