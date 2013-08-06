class Webui::CommentsController < Webui::BaseController

	def packages
		package = Package.get_by_project_and_name(params[:project] , params[:package])
		unless package.nil?
			comments = CommentPackage.where(package_id: package.id)
			render :json => comments
		else
			render_error :status => 404, :errorcode => 'package_returned_nil',
                       :message => "Package returned nil"
		end
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
end