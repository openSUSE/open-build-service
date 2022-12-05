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
  let(:build_failure) { create(:web_notification, :build_failure, subscriber: user) }

  shared_examples 'returning success' do
    it 'returns ok status' do
      expect(response.status).to be 200
    end
  end

  describe 'GET #index' do
    let(:user_to_log_in) { user }
    let(:default_params) { { user_login: username } }

    subject do
      login user_to_log_in
      get :index, params: params
    end

    context 'when no param type is provided' do
      let(:params) { default_params }

      before do
        subject
      end

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

      before do
        subject
      end

      it_behaves_like 'returning success'

      it 'sets @notifications to all delivered notifications regardless of type' do
        expect(assigns[:notifications]).to include(read_notification)
      end
    end

    context "when param type is 'build_failures'" do
      let(:params) { default_params.merge(type: 'build_failures') }

      before do
        subject
      end

      it_behaves_like 'returning success'

      it "sets @notifications to all undelivered notifications of 'build_failures' type" do
        expect(assigns[:notifications]).to include(build_failure)
      end
    end

    context "when param type is 'comments'" do
      let(:params) { default_params.merge(type: 'comments') }

      before do
        subject
      end

      it_behaves_like 'returning success'

      it "sets @notifications to all undelivered notifications of 'comments' type" do
        expect(assigns[:notifications]).to include(comment_for_project_notification,
                                                   comment_for_package_notification,
                                                   comment_for_request_notification)
      end
    end

    context "when param type is 'requests'" do
      let(:params) { default_params.merge(type: 'requests') }

      before do
        subject
      end

      it_behaves_like 'returning success'

      it "sets @notifications to all undelivered notifications of 'requests' type" do
        expect(assigns[:notifications]).to include(state_change_notification.reload,
                                                   creation_notification.reload)
      end
    end

    context "when param type is 'incoming_requests'" do
      let(:admin_user) { create(:admin_user, login: 'king') }
      let(:target_package) { create(:package) }
      let(:source_package) { create(:package, :as_submission_source) }
      let!(:relationship_package_user) { create(:relationship_package_user, user: user, package: target_package) }

      let!(:maintained_request) do
        create(:bs_request_with_submit_action,
               target_package: target_package,
               source_package: source_package,
               creator: admin_user)
      end

      let!(:request_created_notification) { create(:web_notification, :request_created, notifiable: maintained_request, subscriber: user) }
      let!(:review_wanted_notification) { review_notification }

      let(:params) { default_params.merge(type: 'incoming_requests') }

      before do
        subject
      end

      it_behaves_like 'returning success'

      it "sets @notifications to all undelivered notifications of 'incoming_requests' type" do
        expect(assigns[:notifications]).to include(request_created_notification.reload)
      end

      it "@notifications does not include 'review_wanted' notifications for 'incoming_requests' type" do
        expect(assigns[:notifications]).not_to include(review_wanted_notification.reload)
      end
    end

    context "when param type is 'outgoing_requests'" do
      let(:admin_user) { create(:admin_user, login: 'king') }
      let(:target_package) { create(:package) }
      let(:source_package) { create(:package, :as_submission_source) }
      let(:declined_bs_request) do
        create(:declined_bs_request,
               target_package: target_package,
               source_package: source_package,
               creator: user)
      end

      let(:maintained_request) do
        create(:bs_request_with_submit_action,
               target_package: target_package,
               source_package: source_package,
               creator: admin_user)
      end

      let!(:state_change_to_declined_notification) { create(:web_notification, :request_state_change, notifiable: declined_bs_request, subscriber: user) }
      let(:request_created_notification) { create(:web_notification, :request_created, notifiable: maintained_request, subscriber: user) }

      let(:params) { default_params.merge(type: 'outgoing_requests') }

      before do
        subject
      end

      it_behaves_like 'returning success'

      it "sets @notifications to all undelivered notifications of 'outgoing_requests' type" do
        expect(assigns[:notifications]).to include(state_change_to_declined_notification.reload)
      end

      it "@notifications does not include incoming requests for 'outgoing_requests' type" do
        expect(assigns[:notifications]).not_to include(request_created_notification.reload)
      end
    end
  end

  describe 'PUT #update' do
    it { is_expected.to use_after_action(:verify_policy_scoped) }

    context 'when a user marks one of their unread notifications as read' do
      subject! do
        login user_to_log_in
        put :update, params: { notification_ids: [state_change_notification.id], user_login: user_to_log_in.login }, xhr: true
      end

      let(:user_to_log_in) { user }

      it 'succeeds' do
        expect(response).to have_http_status(:ok)
      end

      it 'sets the notification as delivered' do
        expect(state_change_notification.reload.delivered).to be true
      end
    end

    context 'when a user tries to mark other user notifications as read' do
      subject! do
        login user_to_log_in
        put :update, params: { notification_ids: [state_change_notification.id], user_login: user_to_log_in.login }, xhr: true
      end

      let(:user_to_log_in) { other_user }

      it "doesn't set the notification as read" do
        expect(state_change_notification.reload.delivered).to be false
      end
    end

    context 'when a user marks one of their read notifications as unread' do
      subject! do
        login user_to_log_in
        put :update, params: { notification_ids: [read_notification.id], type: 'read', user_login: user_to_log_in.login }, xhr: true
      end

      let(:user_to_log_in) { user }
      let(:read_notification) { create(:web_notification, :request_state_change, subscriber: user_to_log_in, delivered: true) }

      it 'succeeds' do
        expect(response).to have_http_status(:ok)
      end

      it 'sets the notification as not delivered' do
        expect(read_notification.reload.delivered).to be false
      end
    end
  end
end
