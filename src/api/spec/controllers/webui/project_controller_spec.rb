require 'rails_helper'

RSpec.describe Webui::ProjectController do
  describe 'CSRF protection' do
    it 'will protect forms without authenticity token' do
      ActionController::Base.allow_forgery_protection = true # Needed because Rails disables it in test mode by default
      login(create(:confirmed_user, login: 'tom'))
      create(:confirmed_user, login: 'moi')
      expect do
        post :save_person, { userid:  "moi",
                             role:    "maintainer",
                             project: "home:tom",
                             commit:  "Add user" }
      end.to raise_error ActionController::InvalidAuthenticityToken
      ActionController::Base.allow_forgery_protection = false
    end
  end
end
