require 'rails_helper'

RSpec.describe PublicController, vcr: true do
  let(:package) { create(:package_with_file) }

  describe "GET #source_file" do
    it "sends the requested file" do
      get :source_file, project: package.project.name, package: package.name, filename: "somefile.txt"
      expect(response).to have_http_status(:success)
      expect(response.body).to eq(package.source_file("somefile.txt"))
    end
  end
end
