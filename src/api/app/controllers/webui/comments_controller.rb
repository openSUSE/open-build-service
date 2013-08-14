class Webui::CommentsController < Webui::BaseController
	class NotFoundObjectError < APIException
	 setup 'not_found', 404, "Not found"
	end 
	def packages
		package = Package.get_by_project_and_name(params[:project] , params[:package])
		if package.blank?
			raise NotFoundObjectError.new "Package returned nil" 
		end
		comments = CommentPackage.where(package_id: package.id)
		render :json => comments
	end

	def projects
		project = Project.get_by_name(params[:project])
		comments = CommentProject.where(project_id: project.id)
		render :json => comments
	end

	def requests
		comments = CommentRequest.where(bs_request_id: params[:id])
		render :json => comments
	end

	def packages_new
		CommentPackage.save(params)
		render_ok
	end

	def projects_new
		CommentProject.save(params)
		render_ok
	end

	def requests_new
		CommentRequest.save(params)
		render_ok
	end

	def projects_edit
		CommentProject.edit(params)
		render_ok
	end

	def packages_edit
		CommentPackage.edit(params)
		render_ok
	end

	def requests_edit
		CommentRequest.edit(params)
		render_ok
	end

	def projects_delete
		CommentProject.delete(params)
		render_ok
	end

	def packages_delete
		CommentPackage.delete(params)
		render_ok
	end

	def requests_delete
		CommentRequest.delete(params)
		render_ok
	end


end