class CommentsByPackage < Comment
	def self.find(project, package)
		package = Package.get_by_project_and_name(project , package)
		package.comments
	end

	def self.save(params)
		super
		package = Package.get_by_project_and_name(params[:project], params[:package])
		@comment['package_id'] = package.id
		CommentsByPackage.create(@comment)
	end
end
