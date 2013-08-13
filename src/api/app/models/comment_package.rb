class CommentPackage < Comment
	def self.save(params)
		super
		package = Package.get_by_project_and_name(params[:project], params[:package])
		@comment['package_id'] = package.id
		CommentPackage.create(@comment)
	end

	def self.delete_comment(params)
		package = Package.get_by_project_and_name(params[:project], params[:package])
		@object_permission_check = (User.current.can_modify_package?(package) || User.current.is_admin? || User.current.login == params[:user])		
		super
	end
end
