class CommentProject < Comment
	def self.save(params)
		super
		project = Project.get_by_name(params[:project])
		@comment['project_id'] = project.id
		CommentProject.create(@comment)
	end
end