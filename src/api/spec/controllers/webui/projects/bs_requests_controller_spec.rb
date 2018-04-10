# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webui::Projects::BsRequestsController do
  describe 'GET #index' do
    include_context 'a set of bs requests'

    let(:base_params) { { project: source_project, format: :json } }
    let(:context_params) { {} }
    let(:params) { base_params.merge(context_params) }

    before do
      get :index, params: params
    end

    it { expect(response).to have_http_status(:success) }
    it { expect(subject).to render_template(:index) }

    it_behaves_like 'a bs requests data table controller'
    it_behaves_like 'a bs requests data table controller with state and type options'
  end
end
