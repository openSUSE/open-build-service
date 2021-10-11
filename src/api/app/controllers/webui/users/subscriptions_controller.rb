class Webui::Users::SubscriptionsController < Webui::WebuiController
  # TODO: Remove this when we'll refactor kerberos_auth
  before_action :kerberos_auth

  after_action :verify_authorized

  def index
    @subscriptions_form = authorize(subscriptions_form(default_form: params[:default_form]))

    @user = User.session!
    @groups_users = @user.groups_users.includes(:group).order('groups.title')

    respond_to do |format|
      format.html
      format.js
    end
  end

  def update
    @subscriptions_form = authorize(subscriptions_form)

    begin
      groups_users = User.session!.groups_users.includes(:group).find_by(groups: { title: params[:groups].keys }) if params[:groups]
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

  def subscriptions_form(options = {})
    if options[:default_form]
      EventSubscription::Form.new
    else
      EventSubscription::Form.new(User.session)
    end
  end
end
