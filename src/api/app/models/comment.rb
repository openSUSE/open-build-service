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

  def self.remove(params)
    self.update(params[:comment_id], :title => "This comment has been deleted", :body => "", :user => "_nobody_")
  end

end
