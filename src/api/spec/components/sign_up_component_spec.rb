RSpec.describe SignUpComponent, type: :component do
  context 'proxy auth mode enabled' do
    context 'with register page set up' do
      before do
        allow(Configuration).to receive(:proxy_auth_mode_enabled?).and_return(true)
        stub_const('CONFIG', { proxy_auth_register_page: 'http://foo.org' }.with_indifferent_access)
      end

      it { expect(render_inline(described_class.new)).to have_text('Use this link to Sign Up') }
    end

    context 'without register page set up' do
      before do
        allow(Configuration).to receive(:proxy_auth_mode_enabled?).and_return(true)
      end

      it { expect(render_inline(described_class.new)).to have_text('signing up is currently disabled') }
    end
  end
end
