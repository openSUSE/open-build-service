class Webui::ReportsController < Webui::WebuiController
  before_action :require_login
  before_action :set_report, only: :show
  after_action :verify_authorized

  include Webui::ReportablesHelper

  def show
    authorize @report

    handle_notification
  end

  def create
    @user = User.session!
    @report = @user.submitted_reports.new(report_params)
    authorize @report

    @link_id = params[:link_id]

    if @report.save
      if @report.reportable_type == 'Comment' && params[:report_comment_author].present?
        @user.submitted_reports.create!(report_params.merge(reportable_id: @report.reportable.user_id,
                                                            reportable_type: 'User',
                                                            reason: "This user has been reported together with a comment they wrote. Report reason for the comment: #{@report.reason}"))
        flash[:success] = 'Comment and its author both reported successfully'
      else
        flash[:success] = "#{@report.reportable_type} reported successfully"
      end
    else
      flash[:error] = @report.errors.full_messages.to_sentence
    end

    respond_to do |format|
      format.js
    end
  end

  private

  def report_params
    params.require(:report).permit(:reason, :reportable_id, :reportable_type, :category)
  end

  def set_report
    @report = Report.find(params[:id])
  end

  def handle_notification
    return unless User.session && params[:notification_id]

    @current_notification = Notification.find(params[:notification_id])
    authorize @current_notification, :update?, policy_class: NotificationPolicy
  end
end
