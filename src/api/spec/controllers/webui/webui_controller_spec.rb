require 'rails_helper'

RSpec.describe Webui::WebuiController do
  # The webui controller is an abstract controller
  # therefore we need an anoynmous rspec controller
  # https://www.relishapp.com/rspec/rspec-rails/docs/controller-specs/anonymous-controller
  controller do
    before_filter :require_admin, only: :new
    before_filter :require_login, only: :show

    def index
      render text: 'anonymous controller'
    end

    # RSpec anonymous controller only support RESTful routes
    # http://stackoverflow.com/questions/7027518/no-route-matches-rspecs-anonymous-controller
    def new
      render text: 'anonymous controller - requires_admin_privileges'
    end

    def show
      render text: 'anonymous controller - requires_login'
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

  describe 'require_admin before filter' do
    it 'redirects to main page for non privileged user' do
      login(create(:confirmed_user, login: 'confirmed_user'))
      get :new
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq('Requires admin privileges')
    end

    it 'redirects to main page for nobody user' do
      get :new
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to eq('Requires admin privileges')
    end

    it 'for admin' do
      login(create(:admin_user, login: 'admin_user'))
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe 'require_login before filter' do
    it 'redirects to main page for new users' do
      get :show, id: 1
      expect(response).to redirect_to(user_login_path)
      expect(flash[:error]).to eq('Please login to access the requested page.')
    end

    it 'does not redirect for a confirmed user' do
      login(create(:confirmed_user, login: 'eisendieter'))
      get :show, id: 1
      expect(response).to have_http_status(:success)
    end
  end
end
