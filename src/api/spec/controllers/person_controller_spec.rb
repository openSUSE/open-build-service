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
      expect { subject }.not_to(change { user.realname })
    end

    it 'does not change users email address' do
      expect { subject }.not_to(change { user.email })
    end
  end

  describe 'POST #post_userinfo' do
    before do
      login user
    end

    context 'when using default authentication' do
      let!(:old_password) { user.password_digest }

      before do
        request.env['RAW_POST_DATA'] = 'password_has_changed'
        post :post_userinfo, params: { login: user.login, cmd: 'change_password', format: :xml }

        user.reload
      end

      it 'changes the password' do
        expect(old_password).to_not eq(user.password_digest)
      end
    end

    context 'when in LDAP mode' do
      before do
        stub_const('CONFIG', CONFIG.merge('ldap_mode' => :on))
        post :post_userinfo, params: { login: user.login, cmd: 'change_password', format: :xml }
      end

      it 'user is not allowed to change their password' do
        expect(response.header['X-Opensuse-Errorcode']).to eq('change_password_no_permission')
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
