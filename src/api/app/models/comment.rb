class Comment < ActiveRecord::Base
  belongs_to :project
  belongs_to :package
  belongs_to :bs_request

  class NoDataEnteredError < APIException
    setup 'no_data_entered', 403, "No data Entered"
  end
  class NoUserFound < APIException
    setup 'no_user_found', 403, "No user found"
  end
  class WritePermissionError < APIException
    setup "project_write_permission_error"
  end

  def self.save(params)
    @comment = {}
  	@comment['title'] 	= params[:title]
  	@comment['body'] = params[:body]
  	@comment['user'] = params[:user]
  	@comment['parent_id'] = params[:parent_id] if params[:parent_id]

    if @comment['body'].blank?
      raise NoDataEnteredError.new "You didn't add a body to the comment." 
    elsif !@comment['parent_id'] && @comment['title'].blank?
      raise NoDataEnteredError.new "You didnt add a title to the comment"
    elsif @comment['user'].blank?
      raise NoUserFound.new "No user found. Sign in before continuing."
    end
  end

  def self.update_comment(params)

    if params[:update_type] == 'edit' && User.current.login == params[:user]
      self.update(params[:comment_id],:body => params[:body])
    elsif params[:update_type] == 'delete' && @object_permission_check
      self.update(params[:comment_id],:body => "Comment deleted.")
    else
      raise WritePermissionError, "You don't have the permissions to modify the content."
    end

    if params[:update_type] == 'edit' && params[:body].blank?
      raise NoDataEnteredError.new "You didn't add a body to the comment." 
    end

  end

end
