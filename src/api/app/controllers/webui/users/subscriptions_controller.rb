class Webui::Users::SubscriptionsController < Webui::WebuiController
  before_action :require_login

  def index
    @user = User.current
    @groups_users = User.current.groups_users

    @subscriptions_form = subscriptions_form
  end

  def update
    User.current.groups_users.each do |gu|
      gu.email = params[gu.group.title] == '1'
      gu.save
    end

    subscriptions_form.update!(params[:subscriptions])
    flash[:notice] = 'Notifications settings updated'
  rescue ActiveRecord::RecordInvalid
    flash[:error] = 'Notifications settings could not be updated due to an error'
  ensure
    redirect_to action: :index
  end

  private

  def subscriptions_form
    EventSubscription::Form.new(User.current)
  end
end
