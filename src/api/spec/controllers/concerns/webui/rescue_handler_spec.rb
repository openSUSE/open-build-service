# spec/controllers/concerns/webui/rescue_handler_spec.rb

RSpec.describe Webui::RescueHandler do
  controller(ApplicationController) do
    skip_before_action :require_login
    include Webui::RescueHandler

    def index
      raise ActiveRecord::RecordNotUnique
    end
  end

  before do
    routes.draw { get 'index' => 'anonymous#index' }
  end

  describe 'handling ActiveRecord::RecordNotUnique' do
    context 'when request is html' do
      it 'redirects to root_path with error message' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq('This record already exists.')
      end
    end

    context 'when request is xhr' do
      it 'returns conflict status' do
        get :index, xhr: true
        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body['error']).to eq('This record already exists.')
      end
    end
  end
end
