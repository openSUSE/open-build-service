class CommentRequest < Comment
	def self.save(params)
		super
		@comment['bs_request_id'] = params[:request_id]
		CommentRequest.create(@comment)
	end

	def self.update_comment(params)
		@object_permission_check = (User.current.is_admin? || User.current.login == params[:user])		
		super
	end
end