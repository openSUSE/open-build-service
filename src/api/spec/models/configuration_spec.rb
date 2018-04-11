# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Configuration do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:description) }

  it 'creates a new Configuration if no Configuration exists' do
    Configuration.first.destroy
    expect(Configuration.count).to eq(0)
    Configuration.title
    expect(Configuration.count).to eq(1)
  end

  it 'does not create a new Configuration if a Configuration exists ' do
    # The first configuration is created by db/seeds.rb
    expect(Configuration.count).to eq(1)
    Configuration.title
    expect(Configuration.count).to eq(1)
  end

  describe '#delayed_write_to_backend' do
    let(:configuration) { build(:configuration) }

    before do
      allow(Configuration).to receive(:find).and_return(configuration)
      allow(configuration).to receive(:write_to_backend)
    end

    subject! { configuration.delayed_write_to_backend }

    it 'writes to the backend' do
      expect(configuration).to have_received(:write_to_backend)
    end
  end

  describe '#ldap_enabled?' do
    let(:config) { Configuration.first }

    it 'returns true if config option `ldap_mode` is set to :on' do
      stub_const('CONFIG', CONFIG.merge('ldap_mode' => :on))
      expect(config.ldap_enabled?).to eq(true)
    end

    it 'returns false if config option `ldap_mode` is not set to :on' do
      stub_const('CONFIG', CONFIG.merge('ldap_mode' => :off))
      expect(config.ldap_enabled?).to eq(false)
    end
  end

  describe '#passwords_changable?' do
    let(:config) { Configuration.first }

    it 'returns false if config option `change_password` is set to false' do
      allow(config).to receive(:change_password).and_return(false)
      expect(config.passwords_changable?).to eq(false)
    end

    context 'external authentication services' do
      it 'returns false if config option `proxy_auth_mode` is set to :on' do
        stub_const('CONFIG', CONFIG.merge('proxy_auth_mode' => :on))
        expect(config.passwords_changable?).to eq(false)
      end

      context 'in LDAP mode' do
        let(:user) { create(:confirmed_user) }

        before do
          stub_const('CONFIG', CONFIG.merge('ldap_mode' => :on))
        end

        it 'returns false if no user is given' do
          expect(config.passwords_changable?).to eq(false)
        end
        it 'returns false if user is configured to use the LDAP auth service' do
          expect(config.passwords_changable?(user)).to eq(false)
        end
        it 'returns true if user is configured to use local authentication' do
          user.update(ignore_auth_services: true)
          expect(config.passwords_changable?(user)).to eq(true)
        end
      end
    end

    context 'without external authentication services' do
      it 'returns true' do
        expect(config.passwords_changable?).to eq(true)
      end
    end
  end

  describe '#accounts_editable?' do
    let(:config) { Configuration.first }

    context 'proxy_auth_mode is enabled' do
      before do
        stub_const('CONFIG', CONFIG.merge('proxy_auth_mode' => :on))
      end

      it 'returns false if proxy_auth_account_page is not present' do
        expect(config.accounts_editable?).to eq(false)
      end

      it 'returns true if proxy_auth_account_page is present' do
        stub_const('CONFIG', CONFIG.merge('proxy_auth_account_page' => 'https://opensuse.org'))
        expect(config.accounts_editable?).to eq(true)
      end
    end

    context 'ldap_mode is enabled' do
      let(:user) { create(:confirmed_user, ignore_auth_services: true) }

      before do
        stub_const('CONFIG', CONFIG.merge('ldap_mode' => :on))
      end

      it 'returns false' do
        expect(config.accounts_editable?).to eq(false)
      end

      it 'returns true for a user that is configured to ignore_auth_services' do
        expect(config.accounts_editable?(user)).to eq(true)
      end
    end
  end
end
