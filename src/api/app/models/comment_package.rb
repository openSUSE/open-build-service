class CommentPackage < Comment
	def self.save(params)
		super
		package = Package.get_by_project_and_name(params[:project], params[:package])
		@comment['package_id'] = package.id
		CommentPackage.create(@comment)
	end
	def create_notification(params = {})
		super
		params[:project] = self.package.project.name
		params[:package] = self.package.name
		params[:involved_users] = involved_users(:package_id, self.package.id)

		# call the action
		Event::CommentForPackage.create params
	end
end
