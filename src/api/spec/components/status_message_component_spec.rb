require 'rails_helper'

RSpec.describe StatusMessageComponent, type: :component do
  context 'for anonymous user' do
    let(:status_message) { build(:status_message, message: 'Everything is fine', created_at: Time.zone.now) }

    it do
      expect(render_inline(described_class.new(status_message: status_message)).to_html).to have_text('Everything is fine')
    end
  end

  context 'for admin user' do
    let(:status_message) { create(:status_message, message: 'Everything is fine for an admin') }

    before do
      User.session = create(:admin_user)
      render_inline(described_class.new(status_message: status_message)).to_html
    end

    it do
      expect(rendered_component).to have_text('Everything is fine for an admin')
    end

    it do
      expect(rendered_component).to have_text('Delete status message?')
    end
  end
end
