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

  describe '.for_notifiable_package_name' do
    let(:package) { create(:package) }
    let(:other_package) { create(:package) }

    context 'with a direct package notification' do
      let!(:notification_for_package) { create(:notification_for_package, :web_notification, :build_failure, notifiable: package) }
      let!(:notification_for_other_package) { create(:notification_for_package, :web_notification, :build_failure, notifiable: other_package) }

      it 'returns notifications for the given package name' do
        expect(Notification.for_notifiable_package_name(package.name)).to include(notification_for_package)
      end

      it 'excludes notifications for other packages with different names' do
        expect(Notification.for_notifiable_package_name(package.name)).not_to include(notification_for_other_package)
      end
    end

    context 'with a comment notification on a package' do
      let(:comment_on_package) { create(:comment_package, commentable: package) }
      let(:comment_on_other_package) { create(:comment_package, commentable: other_package) }
      let!(:notification_for_comment) { create(:notification_for_comment, :web_notification, :comment_for_package, notifiable: comment_on_package) }
      let!(:notification_for_other_comment) { create(:notification_for_comment, :web_notification, :comment_for_package, notifiable: comment_on_other_package) }

      it 'returns comment notifications for the given package name' do
        expect(Notification.for_notifiable_package_name(package.name)).to include(notification_for_comment)
      end

      it 'excludes comment notifications for other packages' do
        expect(Notification.for_notifiable_package_name(package.name)).not_to include(notification_for_other_comment)
      end
    end

    context 'with a report notification on a package' do
      let(:report_on_package) { create(:report, reportable: package) }
      let(:report_on_other_package) { create(:report, reportable: other_package) }
      let!(:notification_for_report) { create(:notification_for_report, :web_notification, :report_for_package, notifiable: report_on_package) }
      let!(:notification_for_other_report) { create(:notification_for_report, :web_notification, :report_for_package, notifiable: report_on_other_package) }

      it 'returns report notifications for the given package name' do
        expect(Notification.for_notifiable_package_name(package.name)).to include(notification_for_report)
      end

      it 'excludes report notifications for other packages' do
        expect(Notification.for_notifiable_package_name(package.name)).not_to include(notification_for_other_report)
      end
    end

    context 'with a request notification where the package is source or target' do
      let(:bs_request) do
        create(:bs_request_with_submit_action, source_package: package.name, source_project: package.project,
               target_project: package.project, target_package: package.name)
      end
      let(:bs_request_unrelated) do
        create(:bs_request_with_submit_action, source_package: other_package.name, source_project: other_package.project,
               target_project: other_package.project, target_package: other_package.name)
      end
      let!(:notification_for_request) { create(:notification_for_request, :web_notification, :request_state_change, notifiable: bs_request) }
      let!(:notification_unrelated) { create(:notification_for_request, :web_notification, :request_state_change, notifiable: bs_request_unrelated) }

      it 'returns request notifications for the given package name' do
        expect(Notification.for_notifiable_package_name(package.name)).to include(notification_for_request)
      end

      it 'excludes request notifications for other packages' do
        expect(Notification.for_notifiable_package_name(package.name)).not_to include(notification_unrelated)
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
