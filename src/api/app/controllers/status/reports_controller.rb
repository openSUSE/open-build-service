class Status::ReportsController < ApplicationController
  include Status::Concerns::SetCheckable
  before_action :set_status_report
  skip_before_action :require_login, only: [:show]

  # GET /status_reports/published/:project_name/:repository_name/reports/:uuid
  def show
    @checks = @status_report.checks
    @missing_checks = @status_report.missing_checks
  end

  private

  def set_status_report
    if params[:uuid]
      @status_report = @checkable.status_reports.find_by(uuid: params[:uuid])
      return if @status_report
      @error_message = "Status report with uuid '#{params[:uuid]} not found.'"
    else
      @status_report = @checkable.status_reports.first
      return if @status_report
      @error_message = 'Status report not found.'
    end
    render_error(
      status: 404,
      errorcode: 'not_found',
      message: @error_message
    )
  end
end
