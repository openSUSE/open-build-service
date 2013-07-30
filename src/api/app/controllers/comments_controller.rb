class CommentsController < ApplicationController
	include ValidationHelper
	validate_action :all_requests => {:method => :get, :response => :comments}
	validate_action :all_requests => {:method => :put, :request => :comment, :response => :comments}

	class NotFoundObjectError < APIException
		setup 'not_found', 404, "Not found"
	end

	class NoDataEnteredError < APIException
		setup 'no_data_entered', 403, "No data Entered"
	end
	
	def all_requests
		if request.get?

			if params[:package] 
				@package = Package.get_by_project_and_name(params[:project], params[:package])
				@project = params[:project]

				if @package.nil?
					raise NotFoundObjectError.new "Package returned nil"
				end

				@comments = @package.comments
				render :partial => "comments_by_package"
			elsif params[:id]
				@request = BsRequest.find(params[:id])

				if @request.nil?
					raise NotFoundObjectError.new "Request returned nil"
				end

				@comments = @request.comments
				render :partial => "comments_by_request"
			else
				@project = Project.get_by_name(params[:project])

				if @project.nil?
					raise NotFoundObjectError.new "Project returned nil"
				end

				@comments = @project.comments
				render :partial => "comments_by_project"
			end

		elsif request.post?
			new_comments = Xmlhash.parse(request.raw_post)
			logger.info new_comments
			project_from_xml_data = Project.get_by_name(new_comments['project']) if new_comments['object_type'] == "project"
			package_from_xml_data = Package.get_by_project_and_name(new_comments['project'], new_comments['package']) if new_comments['object_type'] == "package"
			request_from_xml_data = BsRequest.find(new_comments['request_id']) if new_comments['object_type'] == "request"

			if new_comments['list']['_content'].nil? || new_comments['list']['_content'].empty? # if no comment body
				raise NoDataEnteredError.new "You didn't add a body to the comment."
			elsif !new_comments['list']['parent_id'] && (new_comments['list']['title'].empty? || new_comments['list']['title'].nil?) # if no title 
				raise NoDataEnteredError.new "You didnt add a title to the comment."
			else
				comment = Comment.new
				comment.title 	= new_comments['list']['title']
				comment.body	= new_comments['list']['_content']
				comment.user 	= new_comments['list']['user']
				comment.object 	= new_comments['object_type']
				comment.project_id = project_from_xml_data.id if new_comments['object_type'] == "project"
				comment.package_id = package_from_xml_data.id if new_comments['object_type'] == "package"
				comment.bs_request_id = request_from_xml_data.id if new_comments['object_type'] == "request"
				comment.parent_id = new_comments['list']['parent_id'] if new_comments['list']['parent_id']
				comment.save
				render_ok
			end
		end
	end
end