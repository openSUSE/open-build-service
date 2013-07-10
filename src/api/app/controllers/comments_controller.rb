class CommentsController < ApplicationController

	def all_requests
		if request.get?

			if params[:package] 
				@package = Package.get_by_project_and_name(params[:project], params[:package])
				
				if @package.nil?
					render_error :status => 404, :errorcode => "not_found",
					:message => "Package returned nil"
					 return
				end

				@comments = Comment.find(:all, :conditions => {:package_id => @package.id})
				render :partial => "comments_by_package"
			elsif params[:id]
				@request = BsRequest.find(params[:id])
				@comments = Comment.find(:all, :conditions => {:bs_request_id => @request.id})
				render :partial => "comments_by_request"
			else
				@project = Project.find_by_name(params[:project])
				@comments = Comment.find(:all, :conditions => {:project_id => @project.id})
				render :partial => "comments_by_project"
			end

		elsif request.put?
			new_comments = ActiveXML::Node.new(request.raw_post)

			project_from_xml_data = Project.find_by_name(new_comments.project) if new_comments.object_type == "project"
			package_from_xml_data = Package.get_by_project_and_name(new_comments.project, new_comments.package) if new_comments.object_type == "package"
			request_from_xml_data = BsRequest.find(new_comments.request_id) if new_comments.object_type == "request"

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