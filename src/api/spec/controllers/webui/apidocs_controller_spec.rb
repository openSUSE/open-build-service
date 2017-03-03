require 'rails_helper'

RSpec.describe Webui::ApidocsController, type: :controller do
  describe "GET index" do
    context "correct setup" do
      render_views

      before do
        get :index
      end

      it { expect(response.body).to have_title('Open Build Service') }
    end

    context "broken setup" do
      let!(:old_location) { CONFIG['apidocs_location'] }

      before do
        CONFIG['apidocs_location'] = '/your/mom'
      end

      after do
        CONFIG['apidocs_location'] = old_location
      end

      it "errors and redirects" do
        expect(Rails.logger).to receive(:error).with(
          "Unable to load apidocs index file from #{CONFIG['apidocs_location']}. Did you create the apidocs?"
        )

        get :index

        expect(flash[:error]).to eq("Unable to load API documentation.")
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
