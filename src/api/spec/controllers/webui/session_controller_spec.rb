# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Webui::SessionController do
  let(:user) { create(:confirmed_user, login: 'tom') }

  shared_examples 'login' do
    before do
      request.env['HTTP_REFERER'] = search_url # Needed for the redirect_to(root_url)
    end

    it 'logs in users with correct credentials' do
      post :create, params: { username: user.login, password: 'buildservice' }
      expect(response).to redirect_to search_url
    end

    it 'tells users about wrong credentials' do
      post :create, params: { username: user.login, password: 'password123' }
      expect(response).to redirect_to session_new_path
      expect(flash[:error]).to eq('Authentication failed')
    end

    it 'tells users about wrong state' do
      user.update(state: :locked)
      post :create, params: { username: user.login, password: 'buildservice' }
      expect(response).to redirect_to root_path
      expect(flash[:error]).to eq('Your account is disabled. Please contact the administrator for details.')
    end

    it 'assigns the current user' do
      post :create, params: { username: user.login, password: 'buildservice' }
      expect(User.current).to eq(user)
      expect(session[:login]).to eq(user.login)
    end
  end

  describe 'POST #create' do
    context 'without referrer' do
      before do
        post :create, params: { username: user.login, password: 'buildservice' }
      end

      it 'redirects to root path' do
        expect(response).to redirect_to root_path
      end
    end

    context 'with deprecated password' do
      let(:user) { create(:user_deprecated_password, state: :confirmed) }

      it_behaves_like 'login'
    end

    context 'with bcrypt password' do
      it_behaves_like 'login'
    end
  end
end
