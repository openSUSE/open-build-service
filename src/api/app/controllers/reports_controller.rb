class ReportsController < ApplicationController
  validate_action show: { response: :report }
  validate_action create: { method: :post, request: :report }
  validate_action update: { method: :put, request: :report }

  before_action :set_report, only: %i[show update destroy]

  # GET /reports
  def index
    @reports = Report.order(:id)
    authorize @reports

    user = User.session
    if user.present? && !(user.admin? || user.moderator? || user.staff?)
      @reports = @reports.where(reporter: user)
    end

    filter_reports

    @reports = @reports.offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 25).to_i)
  end

  # GET /reports/{:id}
  def show
    authorize @report
  end

  # POST /reports
  def create
    report = Report.new(report_params)
    authorize report

    if report.save
      render_ok
    else
      render_error status: 400, errorcode: 'invalid_report', message: report.errors.full_messages.to_sentence
    end
  end

  # PUT /reports/{:id}
  def update
    authorize @report

    if @report.update(report_params)
      render_ok
    else
      render_error status: 400, errorcode: 'invalid_report', message: @report.errors.full_messages.to_sentence
    end
  end

  # DELETE /reports/{:id}
  def destroy
    authorize @report

    @report.destroy!
    render_ok
  end

  private

  def filter_reports
    @reports = @reports.where(reportable_type: params[:reportable_type]) if params[:reportable_type].present? &&
                                                                            params[:reportable_type].in?(Report::REPORTABLE_TYPES.map(&:to_s))

    return if params[:decided].blank?

    if %w[false 0].include?(params[:decided])
      @reports = @reports.where(decision: nil)
    elsif %w[true 1].include?(params[:decided])
      @reports = @reports.where.not(decision: nil)
    end
  end

  def set_report
    @report = Report.find(params[:id])
  end

  def report_params
    xml = Nokogiri::XML(request.raw_post, &:strict)
    report = xml.xpath('//report').first

    if action_name == 'create'
      reportable_id = report.xpath('@reportable_id').text
      reportable_type = report.xpath('@reportable_type').text
      reporter_id = User.session.id
    end
    category = report.xpath('@category').text
    reason = report.text

    { reportable_id: reportable_id, reportable_type: reportable_type, reporter_id: reporter_id, category: category, reason: reason }.compact
  end
end
