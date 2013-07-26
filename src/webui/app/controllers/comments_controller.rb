class CommentsController < ApplicationController
	include ApplicationHelper

	def add_new
		@project = Project.find(params[:project]) if params[:object_type] == "project"
		@package = Package.find( params[:package], project: params[:project] ) if params[:object_type] == "package"
		comment_opts = {}
		comment_opts[:title] 	= params[:title]
		comment_opts[:body] 	= params[:body]
		comment_opts[:user]		= session[:login]
		comment_opts[:project]	= @project.name  if params[:object_type] == "project"
		comment_opts[:project_with_package]	= params[:project]  if params[:object_type] == "package"
		comment_opts[:package]	= @package.name  if params[:object_type] == "package"
		comment_opts[:request_id] 	= params[:request_id] if params[:request_id]
		comment_opts[:object_type] 	= params[:object_type]
		comment_opts[:parent_id]	= params[:parent_id] if params[:parent_id].present?
        comment = Comment.new(comment_opts)
        begin
        	if comment.save
        		flash[:notice] = "Comment was posted successfully"
        	end
        rescue ActiveXML::Transport::Error => e
        	message = e.summary
        	flash[:error] = message
        end

        if params[:object_type] == "package"
        	redirect_to url_for(controller: :package, action: :comments, package: params[:package], project: params[:project])
        elsif params[:object_type] == "request"
        	redirect_to url_for(controller: :request, action: :comments, id: params[:request_id])
        elsif params[:object_type] == "project"
        	redirect_to url_for(controller: :project, action: :comments, project: params[:project])
        end	
	end

	def add_new_reply
		render_dialog
	end
end
