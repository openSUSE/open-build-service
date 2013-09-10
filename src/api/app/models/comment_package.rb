class CommentPackage < Comment
	def self.save(params)
		super
		package = Package.get_by_project_and_name(params[:project], params[:package])
		@comment['package_id'] = package.id
		CommentPackage.create(@comment)
	end
	def create_notification_for_add_comments(params = {})
		super
		params[:project] = self.package.project.name
		params[:package] = self.package.name
		params[:involved_users] = involved_users(:package_id, self.package.id)

		# call the action
		Event::AddCommentForPackage.create params
	end
	def create_notifications_for_deleted_comments(params, keys = {})
		comment = Comment.find(params[:comment_id])
		keys[:commenter] = params[:user]
		keys[:project] = params[:project]
		keys[:package] = params[:package]
		keys[:comment] = comment.body
		keys[:involved_users] = involved_users(:package_id, comment.package_id)

		Event::DeleteCommentForPackage.create keys
	end
end
