require 'rails_helper'

RSpec.describe SourceController, vcr: true do
  describe "POST #global_command_orderkiwirepos" do
    it "is accessible anonymously and forwards backend errors" do
      post :global_command_orderkiwirepos, params: { cmd: "orderkiwirepos" }
      expect(response).to have_http_status(:bad_request)
      expect(Xmlhash.parse(response.body)["summary"]).to eq("read_file: no content attached")
    end
  end
end
