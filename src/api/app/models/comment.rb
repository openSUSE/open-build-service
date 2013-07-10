class Comment < ActiveRecord::Base
  belongs_to :project
  belongs_to :package
  belongs_to :bs_request
  class NoDataEnteredError < APIException
    setup 'no_data_entered', 403, "No data Entered"
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
    end
  end
end
