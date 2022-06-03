require 'rails_helper'

RSpec.describe NotificationActionBarComponent, type: :component do
  context 'for unread notifications' do
    before do
      User.session = create(:user)
      render_inline(described_class.new(type: 'unread', update_path: 'my/notifications', show_read_all_button: true))
    end

    it do
      expect(rendered_content).to have_text("Mark all as 'Read'")
    end

    it do
      expect(rendered_content).to have_selector(:css, 'a[href="my/notifications?update_all=true"]')
    end

    it do
      expect(rendered_content).to have_text("Mark selected as 'Read'")
    end

    it do
      expect(rendered_content).to have_text('Select All')
    end
  end

  context 'for read notifications' do
    before do
      User.session = create(:user)
      render_inline(described_class.new(type: 'read', update_path: 'my/notifications?type=read', show_read_all_button: true))
    end

    it do
      expect(rendered_content).to have_text("Mark all as 'Unread'")
    end

    it do
      expect(rendered_content).to have_selector(:css, 'a[href="my/notifications?type=read&update_all=true"]')
    end

    it do
      expect(rendered_content).to have_text("Mark selected as 'Unread'")
    end

    it do
      expect(rendered_content).to have_text('Select All')
    end
  end
end
