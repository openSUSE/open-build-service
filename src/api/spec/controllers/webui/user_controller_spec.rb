require 'rails_helper'

RSpec.describe Webui::UserController do
  let!(:user) { create(:confirmed_user, login: 'tom') }
  let!(:non_admin_user) { create(:confirmed_user, login: 'moi') }
  let!(:admin_user) { create(:admin_user, login: 'king') }
  let(:deleted_user) { create(:deleted_user) }
  let!(:non_admin_user_request) { create(:set_bugowner_request, priority: 'critical', creator: non_admin_user) }

  describe 'GET #home' do
    skip
  end

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

  describe 'GET #autocomplete' do
    let!(:user) { create(:user, login: 'foobar') }

    it 'returns user login' do
      get :autocomplete, params: { term: 'foo', format: :json }
      expect(JSON.parse(response.body)).to match_array(['foobar'])
    end
  end

  describe 'GET #tokens' do
    let!(:user) { create(:user, login: 'foobaz') }

    it 'returns user token as array of hash' do
      get :tokens, params: { q: 'foo', format: :json }
      expect(JSON.parse(response.body)).to match_array(['name' => 'foobaz'])
    end
  end

  describe 'GET #notifications' do
    skip
  end

  describe 'GET #update_notifications' do
    skip
  end

  describe 'GET #list_users(prefix = nil, hash = nil)' do
    skip
  end
end
