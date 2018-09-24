class Status::ChecksController < ApplicationController
  include Status::Concerns::SetCheckable
  before_action :set_xml_check
  before_action :set_status_report
  before_action :set_check
  after_action :verify_authorized

  # PUT /status_reports/published/:project_name/:repository_name/reports/:uuid
  # PUT /status_reports/requests/:number
  def update
    authorize @status_report

    if @check
      @check.assign_attributes(@xml_check)
    else
      @xml_check[:status_report] = @status_report
      @check = Status::Check.new(@xml_check)
    end

    if @check.save
      render :show
    else
      render_error(status: 422, errorcode: 'invalid_check', message: "Could not save check: #{@check.errors.full_messages.to_sentence}")
    end
  end

  private

  def set_status_report
    if params[:report_uuid]
      @status_report = @checkable.status_reports.find_or_initialize_by(uuid: params[:report_uuid])
    else
      @status_report = @checkable.status_reports.first_or_initialize
    end
  end

  def set_check
    @check = @status_report.checks.find_by(name: @xml_check[:name])
  end

  def set_xml_check
    @xml_check = xml_hash
    return if @xml_check.present?
    render_error status: 404, errorcode: 'empty_body', message: 'Request body is empty!'
  end

  def xml_hash
    result = HashWithIndifferentAccess.new
    parsed_body = Xmlhash.parse(request.body.read)
    return if parsed_body.blank?
    %w[url state short_description name].each { |key| result[key] = parsed_body.value(key) if parsed_body.value(key) }

    result
  end
end
