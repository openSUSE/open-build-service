require 'rails_helper'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe PersonController, vcr: false do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  let!(:old_realname) { user.realname }
  let!(:old_email) { user.email }

  shared_examples "not allowed to change user details" do
    it 'sets an error code' do
      expect(response.header['X-Opensuse-Errorcode']).to eq('change_userinfo_no_permission')
    end

    it 'does not change users real name' do
      expect(user.realname).to eq(old_realname)
    end

    it 'does not change users email address' do
      expect(user.email).to eq(old_email)
    end
  end

  describe 'POST #post_userinfo' do
    context 'when in LDAP mode' do
      before do
        login user
        stub_const('CONFIG', CONFIG.merge({ 'ldap_mode' => :on }))
        post :post_userinfo, params: { login: user.login, cmd: 'change_password', format: :xml }
      end

      it 'user is not allowed to change their password' do
        expect(response.header['X-Opensuse-Errorcode']).to eq('change_password_no_permission')
      end
    end
  end

  describe 'PUT #put_userinfo' do
    let(:xml) {
      <<-XML_DATA
        <userinfo>
          <realname>test name</realname>
          <email>test@test.de</email>
        </userinfo>
      XML_DATA
    }

    context 'when in LDAP mode' do
      before do
        stub_const('CONFIG', CONFIG.merge({ 'ldap_mode' => :on }))
        request.env["RAW_POST_DATA"] = xml
      end

      context 'as an admin' do
        before do
          login admin_user

          put :put_userinfo, params: { login: user.login, format: :xml }
          user.reload
        end

        it_should_behave_like "not allowed to change user details"
      end

      context 'as a user' do
        before do
          login user

          put :put_userinfo, params: { login: user.login, format: :xml }
          user.reload
        end

        it_should_behave_like "not allowed to change user details"
      end
    end
  end
end
