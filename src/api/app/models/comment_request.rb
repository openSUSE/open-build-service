class CommentRequest < Comment
	def self.save(params)
		super
		@comment['bs_request_id'] = params[:id]
		CommentRequest.create(@comment)
	end

	def create_notification_for_add_comments(params = {})
		super
		params[:request_id] = self.bs_request_id
		params[:involved_users] = involved_users(:bs_request_id, self.bs_request_id)

		# call the action
		Event::AddCommentForRequest.create params
	end

	def create_notifications_for_deleted_comments(params, keys = {})
		comment = Comment.find(params[:comment_id])
		keys[:commenter] = params[:user]
		keys[:request_id] = comment.bs_request_id
		keys[:comment] = comment.body
		keys[:involved_users] = involved_users(:bs_request_id, comment.bs_request_id)

		Event::DeleteCommentForRequest.create keys
	end
end