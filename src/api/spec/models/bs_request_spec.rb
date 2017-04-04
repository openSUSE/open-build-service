require 'rails_helper'
require 'nokogiri'

RSpec.describe BsRequest do
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

  describe '#assignreview' do
    context 'from group to user' do
      let(:reviewer) { create(:confirmed_user) }
      let(:group) { create(:group)}
      let(:review) { create(:review, by_group: group.title) }
      let!(:request) { create(:bs_request, creator: reviewer.login, reviews: [review] ) }

      before do
        login(reviewer)
      end

      subject! { request.assignreview({ by_group: group.title, reviewer: reviewer.login }) }

      let(:new_review) { request.reviews.last }

      it { expect(request.reviews.count).to eq(2) }

      it 'creates a new review by the user' do
        expect(new_review.by_user).to eq(reviewer.login)
        expect(new_review.history_elements.last.type).to eq('HistoryElement::ReviewAssigned')
      end

      it 'updates the old review state to accepted and assigns it' do
        expect(review.state).to eq(:accepted)
        expect(review.review_assigned_to).to eq(request.reviews.last)
        expect(review.history_elements.last.type).to eq('HistoryElement::ReviewAccepted')
      end
    end
  end
end
