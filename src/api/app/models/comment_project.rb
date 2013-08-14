class CommentProject < Comment

	def self.save(params)
		super
		project = Project.get_by_name(params[:project])
		@comment['project_id'] = project.id
		CommentProject.create(@comment)
	end

	def self.permission_check!(params)
		project = Project.get_by_name(params[:project])
		@object_permission_check = User.current.can_modify_project?(project)	
		super
	end
end