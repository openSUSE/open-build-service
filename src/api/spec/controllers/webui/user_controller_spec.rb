require 'rails_helper'

RSpec.describe Webui::UserController do
  let!(:user) { create(:confirmed_user, login: 'tom') }
  let!(:non_admin_user) { create(:confirmed_user, login: 'moi') }
  let!(:admin_user) { create(:admin_user, login: 'king') }
  let(:deleted_user) { create(:deleted_user) }
  let!(:non_admin_user_request) { create(:set_bugowner_request, priority: 'critical', creator: non_admin_user) }

  describe 'POST #change_password' do
    before do
      login non_admin_user

      stub_const('CONFIG', CONFIG.merge('ldap_mode' => :on))
      post :change_password
    end

    it 'shows an error message when in LDAP mode' do
      expect(controller).to set_flash[:error]
    end
  end
end
