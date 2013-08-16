class Webui::CommentsController < Webui::BaseController
	class NotFoundObjectError < APIException
	 setup 'not_found', 404, "Not found"
	end
	class CommentNoUserFound < APIException
		setup 'comment_no_user_found', 403, "No user found"
	end
	class CommentNoPermission < APIException
		setup "comment_no_permission_error"
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
		required_parameters :body, :user, :project, :package
		required_parameters :title if !params[:parent_id]

		required_fields :body
		required_fields :title if !params[:parent_id]
		permission_check!(params)

		CommentPackage.save(params)
		render_ok
	end

	def projects_new
		required_parameters :body, :user, :project
		required_parameters :title if !params[:parent_id]

		required_fields :body
		required_fields :title if !params[:parent_id]
		permission_check!(params)

		CommentProject.save(params)
		render_ok
	end

	def requests_new
		required_parameters :body, :user, :id
		required_parameters :title if !params[:parent_id]

		required_fields :body
		required_fields :title if !params[:parent_id]
		permission_check!(params)

		CommentRequest.save(params)
		render_ok
	end

	def projects_edit
		required_parameters :project, :comment_id, :body

		required_fields :body
		permission_check!(params)

		CommentProject.edit(params)
		render_ok
	end

	def packages_edit
		required_parameters :project, :package, :comment_id, :body

		required_fields :body
		permission_check!(params)

		CommentPackage.edit(params)
		render_ok
	end

	def requests_edit
		required_parameters :body, :comment_id, :id

		required_fields :body
		permission_check!(params)

		CommentRequest.edit(params)
		render_ok
	end

	def projects_delete
		delete_action_check(params)
		permission_check!(params)

		CommentProject.delete(params)
		render_ok
	end

	def packages_delete
		delete_action_check(params)
		permission_check!(params)

		CommentPackage.delete(params)
		render_ok
	end

	def requests_delete
		delete_action_check(params)
		permission_check!(params)

		CommentRequest.delete(params)
		render_ok
	end

	private

	def delete_action_check(params)
		required_parameters :user, :comment_id
		params[:body] = "Comment deleted."
		
	end

	def permission_check!(params)
		package = Package.get_by_project_and_name(params[:project], params[:package]) if params[:package]    
		project = Project.get_by_name(params[:project]) if params[:project]
		user = User.new

		unless @http_user.login == params[:user] || @http_user.is_admin? || user.has_local_permission?("change_project", project) || user.has_local_permission?("change_package", package)
			raise CommentNoPermission.new, "You don't have the permissions to modify the content."
		end
	end
end
