RSpec.describe NotificationMarkButtonComponent, type: :component do
  context 'when the notification is read' do
    let(:notification) { create(:notification, delivered: true) }
    let(:selected_filter) { { state: 'read' } }

    before do
      render_inline(described_class.new(notification, selected_filter))
    end

    it 'renders the link with an undo icon' do
      expect(rendered_content).to have_css("a#update_notification_#{notification.id}[title='Mark as \"Unread\"'] > i.fa-undo")
    end

    it 'sets the update path with the right params' do
      expect(rendered_content).to have_css("a#update_notification_#{notification.id}[href='/my/notifications?notification_ids%5B%5D=#{notification.id}&state=read']")
    end
  end

  context 'when the notification is unread' do
    let(:notification) { create(:notification, delivered: false) }
    let(:selected_filter) { { state: 'unread' } }

    before do
      render_inline(described_class.new(notification, selected_filter))
    end

    it 'renders the link with a check mark icon' do
      expect(rendered_content).to have_css("a#update_notification_#{notification.id}[title='Mark as \"Read\"'] > i.fa-check")
    end

    it 'sets the update path with the right params' do
      expect(rendered_content).to have_css("a#update_notification_#{notification.id}[href='/my/notifications?notification_ids%5B%5D=#{notification.id}&state=unread']")
    end
  end
end
