require 'rails_helper'

RSpec.describe Webui::WebuiController do
  # The webui controller is an abstract controller
  # therefore we need an anoynmous rspec controller
  # https://www.relishapp.com/rspec/rspec-rails/docs/controller-specs/anonymous-controller
  controller do
    def index
      render text: 'anonymous controller'
    end
  end

  describe 'GET index as nobody' do
    it 'is allowed when Configuration.anonymous is true' do
      Configuration.update_attributes(anonymous: true)

      get :index
      expect(response).to have_http_status(:success)
    end

    it 'is not allowed when Configuration.anonymous is false' do
      Configuration.update_attributes(anonymous: false)

      get :index
      expect(response).to redirect_to(root_path)
    end
  end

  describe 'GET index as a user' do
    it 'is always allowed' do
      login(create(:confirmed_user))
      Configuration.update_attributes(anonymous: true)

      get :index
      expect(response).to have_http_status(:success)

      Configuration.update_attributes(anonymous: false)

      get :index
      expect(response).to have_http_status(:success)
    end
  end
end
