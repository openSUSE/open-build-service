class PublishedController < ApplicationController
  def binary
    valid_http_methods :get, :post

    # ACL(binary) TODO: this is an uninstrumented call
    pass_to_backend
  end

  def index
    valid_http_methods :get

    answer = Suse::Backend.get("/published/")
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
