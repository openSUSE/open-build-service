class PublishedController < ApplicationController
  def binary
    valid_http_methods :get, :post

    pass_to_backend
  end

  def index
    valid_http_methods :get, :post

    prj = DbProject.find_by_name(params[:project]) if params[:project]
    if prj
      # ACL(index): project link to project with access behaves like target project not existing
      if prj.disabled_for?('access', params[:repository], params[:arch]) and not @http_user.can_access?(prj)
        render_error :status => 404, :errorcode => 'not_found',
        :message => "The link target project #{params[:project]} does not exist"
        return
      end
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
        # ACL(index): projects with flag 'access' are not listed
        accessprjs = DbProject.find( :all, :joins => "LEFT OUTER JOIN flags f ON f.db_project_id = db_projects.id", :conditions => [ "f.flag = 'access'", "ISNULL(f.repo)", "ISNULL(f.architecture_id)"] )
        data.elements.each("directory/entry") do |e|
          project_name = e.attributes["name"]
          prj = DbProject.find_by_name(project_name)
          e.remove if accessprjs.include?(prj) and not @http_user.can_access?(prj)
        end
      render :text => data.to_s, :content_type => "text/xml"
    end
  end
end
