class LabelsController < ApplicationController
  before_action :find_labelable

  # GET /labels/projects/:project_name/packages/:package_name
  # GET /labels/requests/:request_number
  def index
    @labels = @labelable.labels
  end

  private

  def find_labelable
    if params[:request_number]
      @labelable = BsRequest.find_by(number: params[:request_number])
      @message = "Unable to find request '#{params[:request_number]}'"
    else
      @labelable = Package.get_by_project_and_name(params[:project_name], params[:package_name])
      @message = "Unable to find project '#{params[:project_name]}' and package '#{params[:package_name]}'"
    end

    render_error(status: 404, message: @message) && return unless @labelable
  end
end
