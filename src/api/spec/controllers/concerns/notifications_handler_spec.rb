RSpec.describe ApplicationController do # rubocop:disable RSpec/SpecFilePathFormat
  controller do
    include Webui::NotificationsHandler

    def index
      head :ok
    end
  end

  describe '#set_current_notification' do
    let(:user) { create(:user) }
    let(:notification) { create(:notification_for_package, :web_notification, :build_failure, subscriber: user, delivered: false) }

    before do
      session[:login] = user.login
    end

    it 'marks the notification as read when visiting a page' do
      expect do
        get :index, params: { notification_id: notification.id }
      end.to change { notification.reload.delivered }.from(false).to(true)
    end

    it 'sets the current_notification instance variable' do
      get :index, params: { notification_id: notification.id }
      expect(assigns(:current_notification)).to eq(notification)
    end

    it 'does not update already read notifications' do
      notification.update!(delivered: true)
      allow(notification).to receive(:update)
      get :index, params: { notification_id: notification.id }
      expect(notification).not_to have_received(:update)
    end
  end

  describe '#notification_target_path_with_return_to' do
    let(:target_path) { controller.send(:notification_target_path_with_return_to, '/request/show/1?notification_id=2') }
    let(:uri) { URI.parse(target_path) }
    let(:query) { Rack::Utils.parse_nested_query(uri.query) }

    it 'adds the current request path as return_to' do
      get :index, params: { kind: 'requests' }

      expect(uri.path).to eq('/request/show/1')
      expect(query).to include('notification_id' => '2', 'return_to' => request.fullpath)
    end

    it 'returns the original path when the target path is invalid' do
      get :index

      expect(controller.send(:notification_target_path_with_return_to, 'http://[::1')).to eq('http://[::1')
    end
  end

  describe '#notification_return_to_path' do
    it 'returns the notifications path when the return path is invalid' do
      get :index, params: { return_to: 'http://[::1' }

      expect(controller.send(:notification_return_to_path)).to eq(my_notifications_path)
    end
  end
end
