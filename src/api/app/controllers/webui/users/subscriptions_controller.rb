# typed: true
class Webui::Users::SubscriptionsController < Webui::WebuiController
  before_action :require_login

  def index
    switch_to_webui2
    @user = User.session!
    @groups_users = @user.groups_users

    @subscriptions_form = subscriptions_form(default_form: params[:default_form])

    respond_to do |format|
      format.html
      format.js
    end
  end

  def update
    User.session!.groups_users.each do |gu|
      gu.email = params[gu.group.title] == '1'
      gu.save
    end

    subscriptions_form.update!(params[:subscriptions]) if params[:subscriptions]
    flash[:success] = 'Notifications settings updated'
  rescue ActiveRecord::RecordInvalid
    flash[:error] = 'Notifications settings could not be updated due to an error'
  ensure
    respond_to do |format|
      format.html { redirect_to action: :index }
      format.js { render 'webui2/webui/users/subscriptions/update' }
    end
  end

  private

  def subscriptions_form(options = {})
    if options[:default_form]
      EventSubscription::Form.new
    else
      EventSubscription::Form.new(User.session!)
    end
  end
end
