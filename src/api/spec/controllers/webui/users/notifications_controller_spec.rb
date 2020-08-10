require 'rails_helper'

RSpec.describe Webui::Users::NotificationsController do
  let(:username) { 'reynoldsm' }
  let!(:user) { create(:confirmed_user, login: username) }
  let!(:other_user) { create(:confirmed_user) }
  let(:state_change_notification) { create(:web_notification, :request_state_change, subscriber: user) }
  let(:creation_notification) { create(:web_notification, :request_created, subscriber: user) }
  let(:review_notification) { create(:web_notification, :review_wanted, subscriber: user) }
  let(:comment_for_project_notification) { create(:web_notification, :comment_for_project, subscriber: user) }
  let(:comment_for_package_notification) { create(:web_notification, :comment_for_package, subscriber: user) }
  let(:comment_for_request_notification) { create(:web_notification, :comment_for_request, subscriber: user) }
  let(:read_notification) { create(:web_notification, :request_state_change, subscriber: user, delivered: true) }
  let(:notifications_for_other_users) { create(:web_notification, :request_state_change, subscriber: other_user) }

  shared_examples 'returning success' do
    it 'returns ok status' do
      expect(response.status).to be 200
    end
  end

  before do
    Flipper[:notifications_redesign].enable
    login user_to_log_in
  end

  describe 'GET #index' do
    let(:user_to_log_in) { user }
    let(:default_params) { { user_login: username } }

    subject! do
      get :index, params: params
    end

    context 'when no param type is provided' do
      let(:params) { default_params }

      it_behaves_like 'returning success'

      it 'assigns notifications with all notifications' do
        expect(assigns[:notifications]).to include(state_change_notification,
                                                   creation_notification,
                                                   review_notification,
                                                   comment_for_project_notification,
                                                   comment_for_package_notification,
                                                   comment_for_request_notification)
      end

      it 'does not return the notifications for the other user' do
        expect(assigns[:notifications]).not_to include(notifications_for_other_users)
      end
    end

    context "when param type is 'read'" do
      let(:params) { default_params.merge(type: 'read') }

      it_behaves_like 'returning success'

      it 'sets @notifications to all delivered notifications regardless of type' do
        expect(assigns[:notifications]).to include(read_notification)
      end
    end

    context "when param type is 'reviews'" do
      let(:params) { default_params.merge(type: 'reviews') }

      it_behaves_like 'returning success'

      it "sets @notifications to all undelivered notifications of 'review' type" do
        expect(assigns[:notifications]).to include(review_notification)
      end
    end

    context "when param type is 'comments'" do
      let(:params) { default_params.merge(type: 'comments') }

      it_behaves_like 'returning success'

      it "sets @notifications to all undelivered notifications of 'comments' type" do
        expect(assigns[:notifications]).to include(comment_for_project_notification,
                                                   comment_for_package_notification,
                                                   comment_for_request_notification)
      end
    end

    context "when param type is 'requests'" do
      let(:params) { default_params.merge(type: 'requests') }

      it_behaves_like 'returning success'

      it "sets @notifications to all undelivered notifications of 'requests' type" do
        expect(assigns[:notifications]).to include(state_change_notification.reload,
                                                   creation_notification.reload)
      end
    end
  end

  describe 'PUT #update' do
    context 'when a user marks one of his unread notifications as read' do
      subject! do
        put :update, params: { id: state_change_notification.id, user_login: user_to_log_in.login }, xhr: true
      end

      let(:user_to_log_in) { user }

      it 'succeeds' do
        expect(response).to have_http_status(:ok)
      end

      it 'flashes a success message' do
        expect(flash[:success]).to eql('Successfully marked the notification as read')
      end

      it 'sets the notification as delivered' do
        expect(state_change_notification.reload.delivered).to be true
      end
    end

    context 'when a user marks one of his read notifications as unread' do
      subject! do
        put :update, params: { id: read_notification.id, user_login: user_to_log_in.login }, xhr: true
      end

      let(:read_notification) { create(:web_notification, :request_state_change, subscriber: user, delivered: true) }
      let(:user_to_log_in) { user }

      it 'succeeds' do
        expect(response).to have_http_status(:ok)
      end

      it 'flashes a success message' do
        expect(flash[:success]).to eql('Successfully marked the notification as unread')
      end

      it 'sets the notification as not delivered' do
        expect(read_notification.reload.delivered).to be false
      end
    end
  end

  context 'with feature flag not enabled' do
    before do
      Flipper[:notifications_redesign].disable
      login user_to_log_in
    end

    describe 'GET #index' do
      let(:user_to_log_in) { user }
      let(:default_params) { { user_login: username } }

      subject! do
        get :index, params: default_params
      end

      it 'returns not_found status' do
        expect(response.status).to be 404
      end
    end
  end
end
