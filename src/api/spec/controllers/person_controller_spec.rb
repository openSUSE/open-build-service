require 'rails_helper'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe PersonController, vcr: false do
  describe 'POST #post_userinfo' do
    let(:user) { create(:confirmed_user) }

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
end
