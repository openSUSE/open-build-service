class PublishedController < ApplicationController
  def binary
    valid_http_methods :get, :post

    pass_to_backend
  end

  def index
    valid_http_methods :get, :post

    prj = DbProject.find_by_name(params[:project]) if params[:project]
    # ACL(index): prj = nil in case of hidden project
    if params[:project] and prj.nil?
        render_error :status => 404, :errorcode => 'not_found',
        :message => "The link target project #{params[:project]} does not exist"
        return
    end

    # ACL(index): prj = nil in case of hidden project 
    if prj
      if request.post?
        # ACL(index): binarydownload denies access to build files
        if prj.disabled_for?('binarydownload', params[:repository], params[:arch]) and not @http_user.can_download_binaries?(prj)
          render_error :status => 403, :errorcode => "download_binary_no_permission",
          :message => "No permission for binaries from project #{params[:project]}"
          return
        end
      end
      pass_to_backend
      return
    end

    answer = Suse::Backend.get(request.path)
    data=REXML::Document.new(answer.body.to_s)
    if answer
      render :text => data.to_s, :content_type => "text/xml"
    end
  end
end
