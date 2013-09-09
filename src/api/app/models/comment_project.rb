class CommentProject < Comment

	def self.save(params)
		super
		project = Project.get_by_name(params[:project])
		@comment['project_id'] = project.id
		CommentProject.create(@comment)
	end

	def create_notification(params = {})
		super
		params[:project] = self.project.name
		params[:involved_users] = involved_users(:project_id, self.project.id)

		# call the action
		Event::CommentForProject.create params
	end
end
