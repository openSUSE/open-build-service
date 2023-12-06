require 'rails_helper'

RSpec.describe SignUpComponent, type: :component do
  context 'proxy auth mode enabled' do
    context 'with register page set up' do
      before do
        stub_const('CONFIG', { proxy_auth_mode: :on }.with_indifferent_access)
      end

      it { expect(render_inline(described_class.new)).to have_text('signing up is currently disabled') }
    end

    context 'without register page set up' do
      before do
        stub_const('CONFIG', { proxy_auth_mode: :on, proxy_auth_register_page: 'http://foo.org' }.with_indifferent_access)
      end

      it { expect(render_inline(described_class.new)).to have_text('Use this link to Sign Up') }
    end
  end
end
