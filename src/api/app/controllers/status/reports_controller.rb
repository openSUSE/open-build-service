class Status::ReportsController < ApplicationController
  include Status::Concerns::SetCheckable
  before_action :set_status_report
  skip_before_action :require_login, only: [:show]

  # GET /status_reports/published/:project_name/:repository_name/reports/:uuid
  # GET /status_reports/build/:project_name/:repository_name/:arch/reports/:uuid
  def show
    @checks = @status_report.checks
    @missing_checks = @status_report.missing_checks
  end

  private

  def set_status_report
    @status_report = if params[:report_uuid]
                       @checkable.status_reports.find_by!(uuid: params[:report_uuid])
                     else
                       # request reports don't have uuid
                       @checkable.status_reports.first
                     end
  end
end
