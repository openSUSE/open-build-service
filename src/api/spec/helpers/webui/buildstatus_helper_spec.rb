require 'rails_helper'

RSpec.describe Webui::WebuiHelper do
  describe '#get_package_status_description' do
    it "returns a message when a status code is unknown" do
      expect(get_package_status_description("unknown_status")).to eq("status explanation not found")
    end

    it "returns an explanation for a status" do
      expect(get_package_status_description("succeeded")).not_to eq("status explanation not found")
    end
  end
end
