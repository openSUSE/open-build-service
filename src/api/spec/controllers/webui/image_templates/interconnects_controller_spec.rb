require 'rails_helper'
require './spec/support/shared_examples/controllers/image_templates.rb'

RSpec.describe Webui::ImageTemplates::InterconnectsController, type: :controller do
  describe 'GET #index' do
    it_behaves_like 'image templates', 'interconnects/index', :xml

    context 'and format HTML' do
      it 'fails with UnknownFormat' do
        expect do
          get :index, format: :html
        end.to raise_error ActionController::UnknownFormat
      end
    end
  end
end
