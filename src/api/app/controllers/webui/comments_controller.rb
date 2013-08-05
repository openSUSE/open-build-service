class Webui::CommentsController < Webui::BaseController

	def packages
		comments = CommentsByPackage.find(params[:project],params[:package])
		render :json => comments
	end

	def projects
		comments = CommentsByProject.find(params[:project])
		render :json => comments
	end

	def requests
		comments = CommentsByRequest.find(params[:id])
		render :json => comments
	end

	def packages_new
		CommentsByPackage.save(params)
		render_ok
	end

	def projects_new
		CommentsByProject.save(params)
		render_ok
	end

	def requests_new
		CommentsByRequest.save(params)
		render_ok
	end
end