class CommentProject < Comment

	def self.save(params)
		super
		project = Project.get_by_name(params[:project])
		@comment['project_id'] = project.id
		CommentProject.create(@comment)
	end

	def create_notification_for_add_comments(params = {})
		super
		params[:project] = self.project.name
		params[:involved_users] = involved_users(:project_id, self.project.id)

		# call the action
		Event::AddCommentForProject.create params
	end

	def create_notifications_for_deleted_comments(params, keys = {})
		comment = Comment.find(params[:comment_id])
		keys[:commenter] = params[:user]
		keys[:project] = params[:project]
		keys[:comment] = comment.body
		keys[:involved_users] = involved_users(:project_id, comment.project_id)

		Event::DeleteCommentForProject.create keys
	end
end
