require 'rails_helper'

RSpec.describe Person::NotificationsController do
  let(:user) { create(:confirmed_user, :with_home, :in_beta) }

  render_views

  describe 'Check if feature flag is enabled' do
    before do
      toggle_notifications_redesign
      login user
      get :index, format: :xml
    end

    context 'Feature :notifications_redesign is enabled' do
      let(:toggle_notifications_redesign) { Flipper[:notifications_redesign].enable }

      it { expect(response).to have_http_status(:success) }
    end

    context 'Feature :notifications_redesign is disabled' do
      let(:toggle_notifications_redesign) { Flipper[:notifications_redesign].disable }

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'filter check' do
    before do
      Flipper[:notifications_redesign].enable
      login user
      get :index, params: params
    end

    context 'default filter' do
      let(:params) { { format: :xml } }

      it { expect(response).to have_http_status(:success) }
    end

    context 'bad filter' do
      let(:params) { { format: :xml, notifications_type: 'foobar' } }

      it { expect(response).to have_http_status(:bad_request) }
    end
  end

  describe 'index' do
    context 'called by authorized user' do
      let!(:notifications) { create_list(:web_notification, 2, :request_state_change, subscriber: user) }

      before do
        Flipper[:notifications_redesign].enable
        login user
        get :index, format: :xml

        notifications.each do |notification|
          notification.projects << user.home_project
          notification.save
        end
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response.body).to include('<notifications count="2">') }

      context 'filter by project finds results' do
        before do
          login user
          get :index, params: { format: :xml, project: user.home_project_name }
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(response.body).to include('<notifications count="2">') }
      end

      context 'filter by project does not find results' do
        before do
          login user
          get :index, params: { format: :xml, project: 'home:hans' }
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(response.body).to include('<notifications count="0"/>') }
      end
    end

    context 'called by unauthorized user' do
      before do
        get :index, format: :xml
      end

      it { expect(response).to have_http_status(:unauthorized) }
    end
  end

  describe '#update' do
    let!(:notification) { create(:web_notification, :comment_for_package, subscriber: user) }

    before do
      Flipper[:notifications_redesign].enable
    end

    context 'called by an unauthorized user' do
      let(:other_user) { create(:confirmed_user, :in_beta) }

      before do
        login other_user
        put :update, params: { format: :xml, id: notification.id }
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'called by an authorized user' do
      before do
        login user
        put :update, params: { format: :xml, id: notification.id }
      end

      it 'toggles the delivered attribute' do
        expect(notification.reload.delivered).to eq(true)
      end

      it { expect(response).to have_http_status(:success) }
    end

    context "notification doesn't exist" do
      before do
        login user
        put :update, params: { format: :xml, id: notification.id + 1 }
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end
end
