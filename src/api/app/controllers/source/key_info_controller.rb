# frozen_string_literal: true
module Source
  class KeyInfoController < ApplicationController
    def show
      project = Project.get_by_name(params[:project])
      render xml: Project::KeyInfo.key_info_for_project(project)
    end
  end
end
