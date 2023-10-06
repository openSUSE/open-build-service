class Webui::ReportsController < Webui::WebuiController
  before_action :require_login
  after_action :verify_authorized

  def create
    user = User.session!
    report = user.submitted_reports.new(report_params)
    authorize report

    @link_id = params[:link_id]

    if report.save
      flash[:success] = "#{report.reportable_type} reported successfully"
    else
      flash[:error] = report.errors.full_messages.to_sentence
    end

    respond_to do |format|
      format.js
    end
  end

  private

  def report_params
    params.require(:report).permit(:reason, :reportable_id, :reportable_type, :category)
  end
end
