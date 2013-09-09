class CommentRequest < Comment
	def self.save(params)
		super
		@comment['bs_request_id'] = params[:id]
		CommentRequest.create(@comment)
	end

	def create_notification(params = {})
		super
		params[:request_id] = self.bs_request_id
		params[:involved_users] = involved_users(:bs_request_id, self.bs_request_id)

		# call the action
		Event::CommentForRequest.create params
	end
end
