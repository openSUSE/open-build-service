class Comment < ActiveRecord::Base
  belongs_to :project
  belongs_to :package
  belongs_to :bs_request

  def self.save(params)
    @comment = {}
  	@comment['title'] 	= params[:title]
  	@comment['body'] = params[:body]
  	@comment['user'] = params[:user]
  	@comment['parent_id'] = params[:parent_id] if params[:parent_id]
  end

  def self.edit(params)
    self.update(params[:comment_id],:body => params[:body])
  end

  def self.delete(params)
    self.update(params[:comment_id],:body => params[:body] , :user => params[:user])
  end

end
