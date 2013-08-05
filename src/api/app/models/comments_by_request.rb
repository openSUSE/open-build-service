class CommentsByRequest < Comment
	def self.find(bs_request_id)
		request = BsRequest.find(bs_request_id)
		request.comments
	end

	def self.save(params)
		super
		@comment['bs_request_id'] = params[:request_id]
		CommentsByRequest.create(@comment)
	end
end