class CommentsByRequest < Comment
	def self.find(bs_request_id)
		request = BsRequest.find(bs_request_id)
		request.comments
	end
end