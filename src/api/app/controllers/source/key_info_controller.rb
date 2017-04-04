module Source
  class KeyInfoController < ApplicationController
    def show
      project = Project.get_by_name(params[:project])
      path = Project::KeyInfo.backend_url(project.name)

      result = Backend::Connection.get(path)
      render xml: result.body.to_s
    end
  end
end
