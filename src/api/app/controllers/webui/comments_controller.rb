class Webui::CommentsController < Webui::BaseController

	# class NotFoundObjectError < APIException
	# 	setup 'not_found', 404, "Not found"
	# end

	# class NoDataEnteredError < APIException
	# 	setup 'no_data_entered', 403, "No data Entered"
	# end

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

	def package_new
		CommentPackage.save(params[:package])
	end

	def projects_new
		CommentsByProject.save(params)
		render_ok
	end

	def request_new
	end
end