require 'rails_helper'

RSpec.describe Webui::ProjectController do
  describe 'CSRF protection' do
    before do
      # Needed because Rails disables it in test mode by default
      ActionController::Base.allow_forgery_protection = true

      login(create(:confirmed_user, login: 'tom'))
      create(:confirmed_user, login: 'moi')
    end

    after do
      ActionController::Base.allow_forgery_protection = false
    end

    it 'will protect forms without authenticity token' do
      expect { post :save_person, project: "home:tom" }.to raise_error ActionController::InvalidAuthenticityToken
    end
  end
end
