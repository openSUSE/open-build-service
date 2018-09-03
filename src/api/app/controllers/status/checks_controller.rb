class Status::ChecksController < ApplicationController
  before_action :require_status_report
  before_action :require_check, only: [:show, :destroy, :update]
  before_action :set_xml_check, only: [:create, :update]
  skip_before_action :require_login, only: [:show, :index]
  after_action :verify_authorized

  # GET /status/reports/:report_id/checks
  def index
    authorize @status_report
    @checks = @status_report.checks
    @missing_checks = @status_report.missing_checks
  end

  # GET /status/reports/:report_id/checks/:id
  def show
    authorize @status_report
  end

  # POST /status/reports/:report_id/checks
  def create
    authorize @status_report
    @check = @status_report.checks.build(@xml_check)
    if @check.save
      render :show
    else
      render_error(status: 422, errorcode: 'invalid_check', message: "Could not save check: #{@check.errors.full_messages.to_sentence}")
    end
  end

  # PATCH /status/reports/:report_id/checks/:id
  # PUT   /status/reports/:report_id/checks/:id
  def update
    authorize @status_report
    if @check.update(@xml_check)
      render :show
    else
      render_error(status: 422, errorcode: 'invalid_check', message: "Could not save check: #{@check.errors.full_messages.to_sentence}")
    end
  end

  # DELETE /status/reports/:report_id/checks/:id
  def destroy
    authorize @status_report
    if @check.destroy
      render_ok
    else
      render_error(status: 422, errorcode: 'invalid_check', message: "Could not delete check: #{@check.errors.full_messages.to_sentence}")
    end
  end

  private

  def require_status_report
    if params[:report_uuid]
      @status_report = Status::Report.find_by(uuid: params[:report_uuid])
    else
      @status_report = fetch_status_report_from_checkable
    end

    raise ActiveRecord::RecordNotFound unless @status_report
  end

  # Parses <params> and returns a <checkable> object.
  # Raises ActiveRecord::RecordNotFound if no <checkable> was found.
  def fetch_checkable_from_params
    checkable = if params[:repository_name] && params[:project_name]
                  project = Project.find_by(name: params[:project_name])
                  project.repositories.find_by(name: params[:repository_name]) if project
                elsif params[:bs_request_number]
                  BsRequest.with_submit_requests.find_by(number: params[:bs_request_number])
                end

    raise ActiveRecord::RecordNotFound unless checkable

    checkable
  end

  def fetch_status_report_from_checkable
    checkable = fetch_checkable_from_params

    status_report = if params[:report_uuid]
                      checkable.status_reports.find_or_create_by(uuid: params[:report_uuid])
                    else
                      checkable.status_reports.create
                    end
    raise ActiveRecord::RecordNotFound unless status_report

    status_report
  end

  def require_check
    @check = @status_report.checks.find_by(id: params[:id])
    render_error(status: 404, errorcode: 'not_found', message: "Unable to find check with id '#{params[:id]}'") unless @check
  end

  def set_xml_check
    @xml_check = xml_hash
    return if @xml_check.present?
    render_error status: 404, errorcode: 'empty_body', message: 'Request body is empty!'
  end

  def xml_hash
    result = (Xmlhash.parse(request.body.read) || {}).with_indifferent_access
    result.slice(:url, :state, :short_description, :name)
  end
end
