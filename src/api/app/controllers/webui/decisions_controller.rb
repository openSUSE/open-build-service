class Webui::DecisionsController < Webui::WebuiController
  before_action :require_login
  after_action :verify_authorized

  def create
    user = User.session
    @decision = user.decisions.new(decision_params)
    authorize @decision

    return unless safe_to_accept_decision_with_package_deletion?

    if @decision.save
      flash[:success] = 'Decision created successfully '
      if @decision.is_a?(DecisionFavoredWithDeleteRequest) && @decision.bs_request
        flash[:success] += view_context.link_to("(request ##{@decision.bs_request.number})",
                                                request_show_path(@decision.bs_request))
      end
    else
      flash[:error] = @decision.errors.full_messages.to_sentence
    end

    if @decision.deletes_target_record?
      redirect_to root_path
    else
      redirect_back_or_to root_path
    end
  end

  private

  def decision_params
    params.require(:decision).permit(:reason, :type, :force_delete, report_ids: [])
  end

  def safe_to_accept_decision_with_package_deletion?
    return true unless @decision.reports.first&.reportable.is_a?(Package) && @decision.is_a?(DecisionFavoredWithPackageDeletion)

    if !@decision.reports.first.reportable.check_weak_dependencies? && !params[:force_delete]
      flash[:error] = 'The package is used for development, you need to select the force delete option in order to create the decision.'
      redirect_to(report_path(@decision.reports.first))
      return false
    end

    true
  end
end
