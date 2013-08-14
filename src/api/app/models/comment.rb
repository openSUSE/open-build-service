class Comment < ActiveRecord::Base
  belongs_to :project
  belongs_to :package
  belongs_to :bs_request

  class CommentNoDataEntered < APIException
    setup 'comment_no_data_entered', 403, "No data Entered"
  end
  class CommentNoUserFound < APIException
    setup 'comment_no_user_found', 403, "No user found"
  end
  class CommentWritePermissionError < APIException
    setup "comment_write_permission_error"
  end

  def self.fields_check!(params)
    if params[:body].blank?
      raise CommentNoDataEntered.new "You didn't add a body to the comment." 
    elsif params[:user].blank?
      raise CommentNoUserFound.new "No user found. Sign in before continuing."
    end
  end

  def self.permission_check!(params)
    unless User.current.login == params[:user] || User.current.is_admin? || @object_permission_check
      raise CommentWritePermissionError, "You don't have the permissions to modify the content."
    end
    fields_check!(params)
  end

  def self.save(params)
    @comment = {}
  	@comment['title'] 	= params[:title]
  	@comment['body'] = params[:body]
  	@comment['user'] = params[:user]
  	@comment['parent_id'] = params[:parent_id] if params[:parent_id]

    fields_check!(params)
    if !params[:parent_id] && params[:title].blank?
      raise CommentNoDataEntered.new "You didn't add a title to the comment." 
    end
  end

  def self.edit(params)
    permission_check!(params)
    self.update(params[:comment_id],:body => params[:body])
  end

  def self.delete(params)
    params[:body] = "Comment deleted."
    permission_check!(params)
    self.update(params[:comment_id],:body => params[:body] , :user => params[:user])
  end

end
