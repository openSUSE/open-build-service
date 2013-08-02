class CommentsByPackage < Comment
	def self.find(project, package)
		package = Package.get_by_project_and_name(project , package)
		package.comments
	end
end
