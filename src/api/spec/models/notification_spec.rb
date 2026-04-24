RSpec.describe Notification do
  let(:payload) { { comment: 'SuperFakeComment', requestid: 1 } }
  let(:delete_package_event) { Event::DeletePackage.new(payload) }

  describe '#event' do
    subject { create(:notification_for_package, :rss_notification, event_type: 'Event::DeletePackage', event_payload: payload).event }

    it { expect(subject.class).to eq(delete_package_event.class) }
    it { expect(subject.payload).to eq(delete_package_event.payload) }
  end

  describe 'relationship with users' do
    let(:regular_user) { create(:confirmed_user, login: 'foo') }
    let(:notification) { create(:notification_for_request, :rss_notification, subscriber: regular_user) }

    it { expect(regular_user.notifications).to include(notification) }
  end

  describe 'relationship with groups' do
    let(:test_group) { create(:group, title: 'my_test_group') }
    let(:notification) { create(:notification_for_request, :rss_notification, subscriber: test_group) }

    it { expect(test_group.notifications).to include(notification) }
  end

  describe '#user_active?' do
    subject { rss_notification.user_active? }

    let(:rss_notification) { create(:notification_for_request, :rss_notification, subscriber: test_user) }

    context 'when subscriber is away' do
      let(:test_user) { create(:dead_user, login: 'foo') }

      it { expect(subject).to be_falsey }
    end

    context 'when subscribe logged in recently' do
      let(:test_user) { create(:confirmed_user, login: 'foo') }

      it { expect(subject).to be_truthy }
    end
  end

  describe '#any_user_in_group_active?' do
    subject { rss_notification.any_user_in_group_active? }

    let(:rss_notification) { create(:notification_for_request, :rss_notification, subscriber: test_group) }
    let(:test_group) { create(:group) }

    before do
      test_group.add_user(test_user)
    end

    context 'no active user in the group' do
      let!(:test_user) { create(:dead_user, login: 'foo') }

      it { expect(subject).to be_falsey }
    end

    context 'active user in the group' do
      let!(:test_user) { create(:confirmed_user, login: 'foo') }

      it { expect(subject).to be_truthy }
    end
  end

  describe '.for_package_name' do
    let(:package) { create(:package) }

    context 'when the notifiable is a Package directly' do
      let!(:notification) { create(:notification_for_package, :build_failure, notifiable: package) }

      it 'includes the notification' do
        expect(Notification.for_package_name(package.name)).to include(notification)
      end
    end

    context 'when the notifiable is a Comment on the Package' do
      let(:comment) { create(:comment_package, commentable: package) }
      let!(:notification) { create(:notification_for_comment, :comment_for_package, notifiable: comment) }

      it 'includes the notification' do
        expect(Notification.for_package_name(package.name)).to include(notification)
      end
    end

    context 'when the notifiable is a BsRequest with a matching source package' do
      let(:bs_request) { create(:bs_request_with_submit_action, target_package: package.name, source_package: package.name) }
      let!(:notification) { create(:notification_for_request, :request_created, notifiable: bs_request) }

      it 'includes the notification' do
        expect(Notification.for_package_name(package.name)).to include(notification)
      end
    end

    context 'when the notifiable is a Report about the Package' do
      let(:report) { create(:report, reportable: package) }
      let!(:notification) { create(:notification_for_report, :report_for_user, notifiable: report) }

      it 'includes the notification' do
        expect(Notification.for_package_name(package.name)).to include(notification)
      end
    end

    context 'when no notification matches the package name' do
      let(:other_package) { create(:package) }
      let!(:notification) { create(:notification_for_package, :build_failure, notifiable: other_package) }

      it 'does not include the notification' do
        expect(Notification.for_package_name(package.name)).not_to include(notification)
      end
    end
  end

  describe '#build_subscription_reason_text' do
    subject { notification.build_subscription_reason_text(event_type: event_type, receiver_role: receiver_role, event_payload: event_payload) }

    let(:notification) { build(:notification, event_type: event_type, subscription_receiver_role: receiver_role, event_payload: event_payload) }

    context 'when the role is maintainer and event is a build failure on a package' do
      let(:event_type) { 'Event::BuildFail' }
      let(:receiver_role) { 'maintainer' }
      let(:event_payload) { { 'project' => 'home:foo', 'package' => 'obs-server' } }

      it 'includes the event type label' do
        expect(subject).to include('Build Failure')
      end

      it 'includes the role label' do
        expect(subject).to include('Maintainer')
      end

      it 'includes the package name' do
        expect(subject).to include('home:foo/obs-server')
      end
    end

    context 'when the role is maintainer but the payload has only a project (no package)' do
      let(:event_type) { 'Event::RelationshipCreate' }
      let(:receiver_role) { 'maintainer' }
      let(:event_payload) { { 'project' => 'home:foo' } }

      it 'falls back to the project name' do
        expect(subject).to include('home:foo')
      end

      it 'does not include a slash' do
        expect(subject).not_to include('home:foo/')
      end
    end

    context 'when the role is project_watcher' do
      let(:event_type) { 'Event::CommentForProject' }
      let(:receiver_role) { 'project_watcher' }
      let(:event_payload) { { 'project' => 'home:foo', 'comment_body' => 'hi' } }

      it 'includes the role label' do
        expect(subject).to include('Watching the project')
      end

      it 'includes the project name' do
        expect(subject).to include('home:foo')
      end
    end

    context 'when the role is reviewer on a request' do
      let(:event_type) { 'Event::ReviewWanted' }
      let(:receiver_role) { 'reviewer' }
      let(:event_payload) { { 'number' => 42 } }

      it 'includes the role label' do
        expect(subject).to include('Reviewer')
      end

      it 'includes the request number' do
        expect(subject).to include('42')
      end
    end

    context 'when the role is moderator (no specific object)' do
      let(:event_type) { 'Event::ReportForUser' }
      let(:receiver_role) { 'moderator' }
      let(:event_payload) { { 'reportable_type' => 'User' } }

      it 'includes the role label' do
        expect(subject).to include('moderator')
      end
    end
  end

  describe 'Instrumentation' do
    let!(:test_user) { create(:confirmed_user, login: 'foo') }
    let!(:web_notification) { create(:notification_for_request, :web_notification, subscriber: test_user) }

    before do
      allow(RabbitmqBus).to receive(:send_to_bus).with('metrics', 'notification,action=read value=1')
    end

    context 'if delivered change, we should track it' do
      before do
        web_notification.delivered = true
      end

      it do
        web_notification.save
        expect(RabbitmqBus).to have_received(:send_to_bus).with('metrics', 'notification,action=read value=1')
      end
    end

    context 'if delivered does not change, we should not track it' do
      before do
        web_notification.title = 'FOO FOO'
      end

      it do
        web_notification.save
        expect(RabbitmqBus).not_to have_received(:send_to_bus).with('metrics', 'notification,action=read value=1')
      end
    end
  end
end
