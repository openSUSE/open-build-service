class CommentsController < ApplicationController
	include ValidationHelper
	validate_action :all_requests => {:method => :get, :response => :comments}
	validate_action :all_requests => {:method => :put, :request => :comment, :response => :comments}
	

	def all_requests
		if request.get?

			if params[:package] 
				@package = Package.get_by_project_and_name(params[:project], params[:package])
				@project = params[:project]
				if @package.nil?
					render_error :status => 403, :errorcode => "bad_request",
					:message => "Package returned nil"
					 return
				end

				@comments = Comment.where(:package_id => @package.id).to_a
				render :partial => "comments_by_package"
			elsif params[:id]
				@request = BsRequest.find(params[:id])

				if @request.nil?
					render_error :status => 403, :errorcode => "bad_request",
					:message => "Request returned nil"
					return
				end

				@comments = Comment.where(:bs_request_id => @request.id).to_a
				render :partial => "comments_by_request"
			else
				@project = Project.find_by_name(params[:project])

				if @project.nil?
					render_error :status => 403, :errorcode => "bad_request",
					:message => "Project returned nil"
					return
				end

				@comments = Comment.where(:project_id => @project.id).to_a
				render :partial => "comments_by_project"
			end

		elsif request.put?
			new_comments = ActiveXML::Node.new(request.raw_post)

			project_from_xml_data = Project.get_by_name(new_comments.project) if new_comments.object_type == "project"
			package_from_xml_data = Package.get_by_project_and_name(new_comments.project, new_comments.package) if new_comments.object_type == "package"
			request_from_xml_data = BsRequest.find(new_comments.request_id) if new_comments.object_type == "request"

			if new_comments.list.to_s.empty? # if no comment body
				render_error :status => 403, :errorcode => "bad_request",
				:message => "You didn't add a body to the comment."
				return
			elsif !new_comments.list.parent_id && (new_comments.list.title.empty? || new_comments.list.title.nil?) # if no title 
				render_error :status => 403, :errorcode => "bad_request",
				:message => "You didnt add a title to the comment."
				return
			else
				comment = Comment.new
				comment.title 	= new_comments.list.title
				comment.body	= new_comments.list.to_s
				comment.user 	= new_comments.list.user
				comment.object 	= new_comments.object_type
				comment.project_id = project_from_xml_data.id if new_comments.object_type == "project"
				comment.package_id = package_from_xml_data.id if new_comments.object_type == "package"
				comment.bs_request_id = request_from_xml_data.id if new_comments.object_type == "request"
				comment.parent_id = new_comments.list.parent_id if new_comments.list.parent_id
				comment.save
				render_ok
			end
		end
	end
end