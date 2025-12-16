class ReportsController < ApplicationController
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
