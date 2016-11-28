require 'rails_helper'
require 'nokogiri'

RSpec.describe BsRequestAction do
  context '.new_from_xml' do
    let(:user) { create(:user) }
    let(:target) { create(:package) }
    let(:source) { create(:package) }
    let(:input) {
      create(:review_bs_request,
             reviewer: user.login,
             target_project: target.project.name,
             target_package: target.name,
             source_project: source.project.name,
             source_package: source.name)
    }
    let(:doc) { Nokogiri::XML(input.to_axml) }

    context "'when' attribute provided" do
      let!(:updated_when) { 10.years.ago }

      before do
        doc.at_css('state')['when'] = updated_when
        @output = BsRequest.new_from_xml(doc.to_xml)
      end

      # We don't care about milliseconds, therefore we parse to integer
      it { expect(@output.updated_when.to_i).to eq(updated_when.to_i) }
    end

    context "'when' attribute not provided" do
      before do
        doc.xpath('//@when').remove
        @output = BsRequest.new_from_xml(doc.to_xml)
      end

      # We don't care about milliseconds, therefore we parse to integer
      it { expect(@output.updated_when.to_i).to eq(@output.updated_at.to_i) }
    end
  end
end
