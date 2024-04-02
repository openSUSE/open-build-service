class Webui::DecisionsController < Webui::WebuiController
  before_action :require_login
  after_action :verify_authorized

  def create
    user = User.session!
    decision = user.decisions.new(decision_params)
    authorize decision

    if decision.save
      flash[:success] = 'Decision created successfully'
    else
      flash[:error] = decision.errors.full_messages.to_sentence
    end

    redirect_back_or_to root_path
  end

  private

  def decision_params
    params.require(:decision).permit(:reason, :kind, report_ids: [])
  end
end
