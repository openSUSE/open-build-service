class ReportsController < ApplicationController
  validate_action show: { response: :report }

  before_action :set_reportable, only: %i[create index]
  before_action :set_report, only: %i[show update destroy]

  # GET /reports
  def index
    @reports = policy_scope(Report).order(:id)
    authorize @reports

    @reports = @reports.where(reportable: @reportable) if @reportable.present?
    filter_reports

    @reports = @reports.offset(params.fetch(:offset, 0).to_i).limit(params.fetch(:limit, 25).to_i)
  end

  # GET /reports/{:id}
  def show
    authorize @report
  end

  # POST /reports
  def create
    report = @reportable.reports.new(report_params)
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
    if action_name == 'create'
      reportable = @reportable
      reporter_id = User.session.id
    end

    { reportable: reportable, reporter_id: reporter_id, category: params[:category].presence, reason: request.raw_post }.compact
  end

  def set_reportable
    if params[:package_name]
      @reportable = Package.get_by_project_and_name(params[:project_name], params[:package_name])
    elsif params[:project_name]
      @reportable = Project.get_by_name(params[:project_name])
    elsif params[:request_number]
      @reportable = BsRequest.find_by!(number: params[:request_number])
    elsif params[:comment_id]
      @reportable = Comment.find(params[:comment_id])
    elsif params[:user_login]
      @reportable = User.find_by!(login: params[:user_login])
    end
  end
end
