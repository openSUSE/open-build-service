require 'rails_helper'

RSpec.describe Person::NotificationsController do
  render_views

  describe 'Check if user is in beta or feature flag is enabled' do
    context 'user not in beta' do
      let(:user) { create(:confirmed_user, :with_home) }

      before do
        login user
        get :index, format: :xml
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'Feature :notifications_redesign is disabled' do
      let(:user) { create(:confirmed_user, :with_home, :in_beta) }

      before do
        Flipper[:notifications_redesign].disable
        login user
        get :index, format: :xml
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  describe 'index' do
    context 'called by authorized user' do
      let(:user) { create(:confirmed_user, :with_home, :in_beta) }
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
        let(:project) { notifications.first.projects.first }

        before do
          login user
          get :index, params: { format: :xml, project: project }
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(response.body).to include('<notifications count="2">') }
      end

      context 'filter by project doe not find results' do
        let(:project) { notifications.first.projects.first }

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
end
