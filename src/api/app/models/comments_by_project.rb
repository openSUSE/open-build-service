class CommentsByProject < Comment
	def self.find(project)
		project = Project.get_by_name(project)
		project.comments
	end

	def self.save(params)
		super
		project = Project.get_by_name(params[:project])
		@comment.project_id = project.id
		@comment.save
	end
end