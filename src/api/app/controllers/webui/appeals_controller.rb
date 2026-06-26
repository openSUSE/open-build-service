class Webui::AppealsController < Webui::WebuiController
  include Webui::NotificationsHandler

  after_action :verify_authorized

  def show
    @appeal = Appeal.find(params[:id])

    authorize @appeal
    @current_notification = handle_notification
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
end
