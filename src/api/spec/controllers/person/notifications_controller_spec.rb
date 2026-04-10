RSpec.describe Person::NotificationsController do
  let(:user) { create(:confirmed_user, :with_home, :in_beta) }

  render_views

  describe 'filter check' do
    before do
      login user
      get :index, params: params
    end

    context 'default filter' do
      let(:params) { { format: :xml } }

      it { expect(response).to have_http_status(:success) }
    end

    context 'bad filter' do
      let(:params) { { format: :xml, kind: 'foobar' } }

      it { expect(response).to have_http_status(:bad_request) }
    end
  end

  describe 'index' do
    context 'called by authorized user' do
      let!(:notifications) { create_list(:notification_for_request, 2, :web_notification, :request_state_change, subscriber: user) }

      before do
        login user
        get :index, format: :xml

        notifications.each do |notification|
          notification.projects << user.home_project
          notification.save
        end
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response.body).to include('<notifications count="2">') }

      context 'filter by kind' do
        let!(:notifications) { create_list(:notification_for_request, 2, :web_notification, :request_state_change, subscriber: user, delivered: true) }

        before do
          login user
          get :index, params: { format: :xml, state: 'read' }
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(response.body).to include('<notifications count="2">') }
      end

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
    let!(:notification) { create(:notification_for_comment, :web_notification, :comment_for_package, subscriber: user) }

    context 'called by an unauthorized user' do
      let(:other_user) { create(:confirmed_user, :in_beta) }

      before do
        login other_user
        put :update, params: { format: :xml, id: notification.id }
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'called by an authorized user' do
      subject { put :update, params: { format: :xml, id: notification.id } }

      let(:cache_key) { [user.id, 'unread_notification_count'] }

      before do
        login user
      end

      it 'toggles the delivered attribute' do
        subject
        expect(notification.reload.delivered).to be(true)
        expect(response).to have_http_status(:success)
      end

      it 'clears the cache entry for the unread notification count' do
        allow(Rails.cache).to receive(:delete).and_call_original
        # Pre-fill the cache to be extra sure
        Rails.cache.write(cache_key, 123)
        subject
        expect(Rails.cache).to have_received(:delete).with(cache_key)
        # Verify the cache entry is gone
        expect(Rails.cache.read(cache_key)).to be_nil
      end
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
