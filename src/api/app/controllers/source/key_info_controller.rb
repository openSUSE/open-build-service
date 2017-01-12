module Source
  class KeyInfoController < ApplicationController
    def show
      project = Project.get_by_name(params[:project])

      path = request.path_info
      pass_to_backend(path)
    end
  end
end
