require 'rails_helper'

RSpec.describe Webui::NotificationHelper do
  describe '#mark_as_read_or_unread_button' do
    let(:link) { mark_as_read_or_unread_button(notification) }

    context 'for unread notification' do
      let(:notification) { create(:web_notification, delivered: false) }

      it { expect(link).to include(my_notifications_path(notification_ids: [notification.id])) }
      it { expect(link).to include('type=unread') }
      it { expect(link).to include('Mark as read') }
      it { expect(link).to include('fa-check fas') }
    end

    context 'for read notification' do
      let(:notification) { create(:web_notification, delivered: true) }

      it { expect(link).to include(my_notifications_path(notification_ids: [notification.id])) }
      it { expect(link).to include('type=read') }
      it { expect(link).to include('Mark as unread') }
      it { expect(link).to include('fa-undo fas') }
    end
  end
end
