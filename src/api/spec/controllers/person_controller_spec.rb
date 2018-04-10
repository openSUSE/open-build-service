# frozen_string_literal: true

require 'rails_helper'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe PersonController, vcr: false do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  shared_examples 'not allowed to change user details' do
    it 'sets an error code' do
      subject
      expect(response.header['X-Opensuse-Errorcode']).to eq('change_userinfo_no_permission')
    end

    it 'does not change users real name' do
      expect { subject }.not_to(change(user, :realname))
    end

    it 'does not change users email address' do
      expect { subject }.not_to(change(user, :email))
    end
  end

  describe 'GET #get_userinfo' do
    context 'called by a user' do
      before do
        login user
        get :get_userinfo, params: { login: user.login }
      end

      it 'shows all user related data' do
        assert_select 'person' do
          assert_select 'login', text: user.login
          assert_select 'email', text: user.email
          assert_select 'realname', text: user.realname
          assert_select 'state', text: 'confirmed'
        end
      end

      it 'shows not the ignore_auth_services flag' do
        assert_select 'person' do
          assert_select 'ignore_auth_services', text: user.ignore_auth_services, count: 0
        end
      end
    end

    context 'called by an admin' do
      before do
        login user
        get :get_userinfo, params: { login: user.login }
      end

      it 'shows all user related data' do
        assert_select 'person' do
          assert_select 'login', text: user.login
          assert_select 'email', text: user.email
          assert_select 'realname', text: user.realname
          assert_select 'state', text: 'confirmed'
        end
      end

      it 'shows not the ignore_auth_services flag' do
        assert_select 'person' do
          assert_select 'ignore_auth_services', text: user.ignore_auth_services, count: 0
        end
      end
    end
  end

  describe 'POST #post_userinfo' do
    let!(:old_password_digest) { user.password_digest }

    before do
      login user
    end

    context 'when using default authentication' do
      before do
        request.env['RAW_POST_DATA'] = 'password_has_changed'
        post :post_userinfo, params: { login: user.login, cmd: 'change_password', format: :xml }
      end

      it 'changes the password' do
        expect(old_password_digest).not_to eq(user.reload.password_digest)
      end
    end

    context 'when in LDAP mode' do
      before do
        request.env['RAW_POST_DATA'] = 'password_has_changed'
        stub_const('CONFIG', CONFIG.merge('ldap_mode' => :on))
      end

      context 'and the user is configured to authorize on the LDAP server' do
        before do
          post :post_userinfo, params: { login: user.login, cmd: 'change_password', format: :xml }
        end

        it { expect(response.header['X-Opensuse-Errorcode']).to eq('change_password_no_permission') }
        it { expect(old_password_digest).to eq(user.reload.password_digest) }
      end

      context 'and the user is configured to authorize locally' do
        before do
          user.update(ignore_auth_services: true)
          post :post_userinfo, params: { login: user.login, cmd: 'change_password', format: :xml }
        end

        it { expect(old_password_digest).not_to eq(user.reload.password_digest) }
      end
    end
  end

  describe 'PUT #put_userinfo' do
    let(:xml) do
      <<-XML_DATA
        <userinfo>
          <realname>test name</realname>
          <email>test@test.de</email>
        </userinfo>
      XML_DATA
    end

    context 'when in LDAP mode' do
      before do
        stub_const('CONFIG', CONFIG.merge('ldap_mode' => :on))
        request.env['RAW_POST_DATA'] = xml
      end

      subject { put :put_userinfo, params: { login: user.login, format: :xml } }

      context 'as an admin' do
        before do
          login admin_user
        end

        it_should_behave_like 'not allowed to change user details'
      end

      context 'as a user' do
        before do
          login user
        end

        it_should_behave_like 'not allowed to change user details'
      end
    end
  end

  describe 'POST #register' do
    context 'when in LDAP mode' do
      before do
        stub_const('CONFIG', CONFIG.merge('ldap_mode' => :on))
      end

      subject! { post :register }

      it 'sets an error code' do
        expect(response.header['X-Opensuse-Errorcode']).to eq('permission_denied')
      end
    end
  end

  describe 'POST #command' do
    context 'with param cmd = register' do
      context 'when in LDAP mode' do
        before do
          stub_const('CONFIG', CONFIG.merge('ldap_mode' => :on))
        end

        subject! { post :command, params: { cmd: 'register' } }

        it 'sets an error code' do
          expect(response.header['X-Opensuse-Errorcode']).to eq('permission_denied')
        end
      end
    end
  end
end
