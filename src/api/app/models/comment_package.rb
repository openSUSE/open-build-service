class CommentPackage < Comment
	def self.save(params)
		super
		package = Package.get_by_project_and_name(params[:project], params[:package])
		@comment['package_id'] = package.id
		CommentPackage.create(@comment)
	end

	def self.permission_check!(params)
		package = Package.get_by_project_and_name(params[:project], params[:package])
		@object_permission_check = User.current.can_modify_package?(package)
		super
	end
end
