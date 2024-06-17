RSpec.describe Webui::NotificationHelper do
  describe '#mark_as_read_or_unread_button' do
    let(:link) { mark_as_read_or_unread_button(notification) }

    context 'for unread notification' do
      let(:notification) { create(:web_notification, delivered: false) }

      it { expect(link).to include(my_notifications_path(notification_ids: [notification.id])) }
      it { expect(link).to include('state=unread') }
      it { expect(link).to include('Mark as read') }
      it { expect(link).to include('fa-check fas') }
    end

    context 'for read notification' do
      let(:notification) { create(:web_notification, delivered: true) }

      it { expect(link).to include(my_notifications_path(notification_ids: [notification.id])) }
      it { expect(link).to include('state=read') }
      it { expect(link).to include('Mark as unread') }
      it { expect(link).to include('fa-undo fas') }
    end
  end

  describe '#excerpt' do
    let(:user) { create(:user) }

    context 'notification for a BsRequest without a description' do
      let(:request) { create(:bs_request_with_submit_action, description: nil) }
      let(:notification) { create(:web_notification, :request_created, notifiable: request, subscriber: user) }

      it do
        expect(excerpt(notification)).to have_text('')
      end
    end

    context 'notification for a short comment' do
      let(:comment) { create(:comment_project, body: 'Nice project!') }
      let(:notification) { create(:web_notification, :comment_for_project, notifiable: comment, subscriber: user) }

      it do
        expect(excerpt(notification)).to have_text('Nice project!')
      end
    end

    context 'notification for a long description' do
      let(:report) { create(:report, reason: Faker::Lorem.characters(number: 120)) }
      let(:notification) { create(:web_notification, :create_report, notifiable: report, subscriber: user) }

      it do
        expect(excerpt(notification)).to have_text('...')
      end
    end
  end
end
