module Webui2::ProjectController
  def webui2_show
    @remote_projects = Project.where.not(remoteurl: nil).pluck(:id, :name, :title)
  end
end
