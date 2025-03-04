RSpec.describe Configuration do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:description) }

  describe '#delayed_write_to_backend' do
    let(:configuration) { build(:configuration) }

    before do
      allow(Configuration).to receive(:find).and_return(configuration)
      allow(configuration).to receive(:write_to_backend)

      configuration.delayed_write_to_backend
    end

    it 'writes to the backend' do
      expect(configuration).to have_received(:write_to_backend)
    end
  end

  describe '#passwords_changable?' do
    context 'config option `change_password` is set to false' do
      before do
        Configuration.update(change_password: false)
      end

      it 'returns false' do
        expect(Configuration.passwords_changable?).to be(false)
      end
    end

    context 'external authentication services' do
      context 'in proxy auth mode' do
        before do
          stub_const('CONFIG', { proxy_auth_mode: :on, proxy_auth_login_page: '/', proxy_auth_logout_page: '/' }.with_indifferent_access)
        end

        it 'returns false if config option `proxy_auth_mode` is set to :on' do
          expect(Configuration.passwords_changable?).to be(false)
        end
      end
    end

    context 'without external authentication services' do
      it 'returns true' do
        expect(Configuration.passwords_changable?).to be(true)
      end
    end
  end

  describe '#accounts_editable?' do
    context 'proxy_auth_mode is enabled' do
      it 'returns false if proxy_auth_account_page is not present' do
        stub_const('CONFIG', { proxy_auth_mode: :on, proxy_auth_login_page: '/', proxy_auth_logout_page: '/' }.with_indifferent_access)
        expect(Configuration.accounts_editable?).to be(false)
      end

      it 'returns true if proxy_auth_account_page is present' do
        stub_const('CONFIG', CONFIG.merge('proxy_auth_account_page' => 'https://opensuse.org'))
        expect(Configuration.accounts_editable?).to be(true)
      end
    end
  end
end
