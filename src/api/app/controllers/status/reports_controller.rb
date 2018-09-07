class Status::ReportsController < ApplicationController
  before_action :set_status_report, only: [:show, :destroy]
  before_action :require_checkable
  skip_before_action :require_login, only: [:show, :index]
  after_action :verify_authorized, except: [:show, :index]

  # GET /status/request/:bs_request_number/reports
  # GET /status/projects/:project_name/repositories/:repository_name/reports
  def index
    @status_reports = @checkable.status_reports
  end

  # GET /status/reports/:id
  # GET /status/request/:bs_request_number/reports/:id
  # GET /status/projects/:project_name/repositories/:repository_name/reports/:id
  def show
    render locals: { status_report: @status_report }
  end

  # DELETE /status/reports/:id
  # DELETE /status/request/:bs_request_number/reports/:id
  # DELETE /status/projects/:project_name/repositories/:repository_name/reports/:id
  def destroy
    authorize @status_report
    if @status_report.destroy
      render_ok
    else
      render_error(status: 422, errorcode: 'invalid_status_report',
                   message: "Could not delete status report: #{@status_report.errors.full_messages.to_sentence}")
    end
  end

  private

  def set_status_report
    @status_report = Status::Report.find_by(uuid: params[:uuid])
    raise ActiveRecord::RecordNotFound unless @status_report
  end

  def require_checkable
    if params[:repository_name] && params[:project_name]
      project = Project.find_by(name: params[:project_name])
      @checkable = project.repositories.find_by(name: params[:repository_name]) if project
    elsif params[:bs_request_number]
      @checkable = BsRequest.with_submit_requests.find_by(number: params[:bs_request_number])
    end

    render_error(status: 404, errorcode: 'not_found', message: 'Unable to find checkable') unless @checkable
  end

  def xml_hash
    parsed_body = Xmlhash.parse(request.body.read)
    return {} unless parsed_body.value(:uuid)

    { uuid: parsed_body.value(:uuid) }
  end
end
