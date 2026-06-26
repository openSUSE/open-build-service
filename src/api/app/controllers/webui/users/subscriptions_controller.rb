class Webui::Users::SubscriptionsController < Webui::WebuiController
  before_action :require_login
  before_action :set_subscriptions_form

  after_action :verify_authorized, except: [:index]

  def index
    @user = User.session
    @groups_users = @user.groups_users.includes(:group).order('groups.title')
  end

  def update
    authorize @subscriptions_form

    begin
      groups_users = User.session.groups_users.includes(:group).find_by(groups: { title: params[:groups].keys }) if params[:groups]
      groups_users.update!(params[:groups][groups_users.group.title].slice(:web, :email).permit!) if groups_users

      @subscriptions_form.update!(params[:subscriptions]) if params[:subscriptions]
      flash.now[:success] = 'Notifications settings updated'
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:error] = "Notifications settings could not be updated due to an error: #{e.message}"
    end

    respond_to do |format|
      format.html { redirect_to action: :index }
      format.js { render 'webui/users/subscriptions/update' }
    end
  end

  private

  def set_subscriptions_form
    @subscriptions_form = EventSubscription::Form.new(User.session)
  end
end
