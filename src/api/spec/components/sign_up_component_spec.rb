require 'rails_helper'

RSpec.describe SignUpComponent, type: :component do
  context 'signing up disabled' do
    let(:config) { { 'proxy_auth_mode' => :on } }

    it do
      expect(render_inline(described_class.new(config: config))).to have_text('signing up is currently disabled')
    end

    context 'there is a proxy auth register page' do
      let(:config) { { 'proxy_auth_mode' => :on, 'proxy_auth_register_page' => 'http://foo.org' } }

      it do
        expect(render_inline(described_class.new(config: config))).to have_text('Use this link to Sign Up')
      end
    end
  end
end
