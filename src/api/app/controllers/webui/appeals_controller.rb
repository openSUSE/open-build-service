class Webui::AppealsController < Webui::WebuiController
  after_action :verify_authorized
  before_action :handle_notification, only: :show

  def show
    @appeal = Appeal.find(params[:id])

    authorize @appeal
  end

  def new
    @decision = Decision.find(decision_params)
    @appeal = Appeal.new(decision: @decision, appellant: User.session)

    authorize @appeal
  end

  def create
    @decision = Decision.find(decision_params)
    @appeal = Appeal.new(appeal_params)
    @appeal.decision = @decision
    @appeal.appellant = User.session

    authorize @appeal

    if @appeal.save
      flash[:success] = 'Appeal created successfully!'
      redirect_to @appeal
    else
      flash[:error] = @appeal.errors.full_messages.to_sentence
      render 'new'
    end
  end

  private

  def decision_params
    params.require(:decision_id)
  end

  def appeal_params
    params.require(:appeal).permit(:reason)
  end

  def handle_notification
    return unless User.session && params[:notification_id]

    @current_notification = Notification.find(params[:notification_id])
    authorize @current_notification, :update?, policy_class: NotificationPolicy
  end
end
