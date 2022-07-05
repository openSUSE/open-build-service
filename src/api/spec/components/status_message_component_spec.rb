require 'rails_helper'

RSpec.describe StatusMessageComponent, type: :component do
  context 'for anonymous user' do
    let(:status_message) { build(:status_message, message: 'Everything is fine', created_at: Time.zone.now) }

    it do
      expect(render_inline(described_class.new(status_message: status_message))).to have_text('Everything is fine')
    end
  end

  context 'for admin user' do
    let(:status_message) { create(:status_message, message: 'Everything is fine for an admin') }

    before do
      User.session = create(:admin_user)
      render_inline(described_class.new(status_message: status_message))
    end

    it do
      expect(rendered_content).to have_text('Everything is fine for an admin')
    end
  end
end
