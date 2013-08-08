class CommentProject < Comment

	def self.save(params)
		super
		project = Project.get_by_name(params[:project])
		@comment['project_id'] = project.id
		CommentProject.create(@comment)
	end

	def self.update_comment(params)
		project = Project.get_by_name(params[:project])
		@object_permission_check = (User.current.can_modify_project?(project) || User.current.is_admin? || User.current.login == params[:user])		
		super
	end
end