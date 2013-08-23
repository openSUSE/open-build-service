class CommentRequest < Comment
	def self.save(params)
		super
                @comment['bs_request_id'] = params[:id]
		CommentRequest.create(@comment)
	end
end
