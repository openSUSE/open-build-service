require 'rails_helper'
require 'nokogiri'

RSpec.describe BsRequest do
  context '.new_from_xml' do
    let(:user) { create(:user) }
    let(:target) { create(:package) }
    let(:source) { create(:package) }
    let(:input) do
      create(:review_bs_request,
             reviewer: user.login,
             target_project: target.project.name,
             target_package: target.name,
             source_project: source.project.name,
             source_package: source.name)
    end
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
      let(:group) { create(:group) }
      let(:review) { create(:review, by_group: group.title) }
      let!(:request) { create(:bs_request, creator: reviewer.login, reviews: [review]) }

      before do
        login(reviewer)
      end

      subject! { request.assignreview(by_group: group.title, reviewer: reviewer.login) }

      let(:new_review) { request.reviews.last }

      it { expect(request.reviews.count).to eq(2) }

      it 'creates a new review by the user' do
        expect(new_review.by_user).to eq(reviewer.login)
        expect(new_review.history_elements.last.type).to eq('HistoryElement::ReviewAssigned')
      end

      it 'updates the old review state to accepted and assigns it' do
        expect(review.state).to eq(:accepted)
        expect(review.review_assigned_to).to eq(request.reviews.last)
        expect(review.reviewer).to eq(reviewer.login)
        expect(review.history_elements.last.type).to eq('HistoryElement::ReviewAccepted')
      end
    end
  end

  describe '#addreview' do
    let(:reviewer) { create(:confirmed_user) }
    let(:group) { create(:group) }
    let!(:request) { create(:bs_request, creator: reviewer.login) }

    before do
      login(reviewer)
      request.addreview(by_group: group.title)
    end

    subject { Review.last }
    let(:history_element) { HistoryElement::RequestReviewAdded.last }

    it { expect(subject.state).to eq(:new) }
    it { expect(subject.by_group).to eq(group.title) }
    it { expect(subject.reviewer).to eq(reviewer.login) }
    it { expect(subject.creator).to eq(reviewer.login) }

    it { expect(history_element.request).to eq(request) }
    it { expect(history_element.user).to eq(reviewer) }

    it { expect(request.state).to eq(:review) }
    it { expect(request.commenter).to eq(reviewer.login) }
  end

  describe '#changestate' do
    let!(:request) { create(:bs_request) }
    let(:admin) { create(:admin_user) }

    context 'to delete state' do
      before do
        User.current = admin
        request.change_state(newstate: 'deleted')
      end

      it 'changes state to deleted' do
        expect(request.state).to eq(:deleted)
      end

      it 'creates a HistoryElement::RequestDeleted' do
        expect(request.history_elements.first.type).to eq('HistoryElement::RequestDeleted')
      end
    end
  end

  describe '#update_cache' do
    RSpec.shared_examples "the subject's cache is reset when it's request changes" do
      before do
        Timecop.travel(1.minute)
        @cache_key = user.cache_key
        request.state = :review
        request.save
        user.reload
      end

      it { expect(user.cache_key).not_to eq(@cache_key) }
    end

    context 'creator of bs_request' do
      let!(:request) { create(:bs_request, creator: user.login) }
      let(:user) { create(:admin_user) }

      it_should_behave_like "the subject's cache is reset when it's request changes"
    end

    context 'direct maintainer of a target_project' do
      let(:target_project) { create(:project) }
      let(:source_package) { create(:package) }
      let(:source_project) { source_package.project }

      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project.name,
               source_project: source_project.name,
               source_package: source_package.name)
      end

      let!(:relationship_project_user) { create(:relationship_project_user, project: target_project) }
      let(:user) { relationship_project_user.user }

      it_should_behave_like "the subject's cache is reset when it's request changes"
    end

    context 'group maintainer of a target_project' do
      let(:target_project) { create(:project) }
      let(:source_package) { create(:package) }
      let(:source_project) { source_package.project }

      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project.name,
               source_project: source_project.name,
               source_package: source_package.name)
      end

      let(:relationship_project_group) { create(:relationship_project_group, project: target_project) }
      let(:group) { relationship_project_group.group }
      let!(:groups_user) { create(:groups_user, group: group) }
      let(:user) { groups_user.user }

      it_should_behave_like "the subject's cache is reset when it's request changes" do
        subject { user }
      end
      it_should_behave_like "the subject's cache is reset when it's request changes" do
        subject { group }
      end
    end

    context 'direct maintainer of a target_package' do
      let(:target_package) { create(:package) }
      let(:target_project) { target_package.project }
      let(:source_package) { create(:package) }
      let(:source_project) { source_package.project }

      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project.name,
               target_package: target_package.name,
               source_project: source_project.name,
               source_package: source_package.name)
      end

      let!(:relationship_package_user) { create(:relationship_package_user, package: target_package) }
      let(:user) { relationship_package_user.user }

      it_should_behave_like "the subject's cache is reset when it's request changes"
    end

    context 'group maintainer of a target_package' do
      let(:target_package) { create(:package) }
      let(:target_project) { target_package.project }
      let(:source_package) { create(:package) }
      let(:source_project) { source_package.project }

      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project.name,
               target_package: target_package.name,
               source_project: source_project.name,
               source_package: source_package.name)
      end

      let(:relationship_package_group) { create(:relationship_package_group, package: target_package) }
      let(:group) { relationship_package_group.group }
      let!(:groups_user) { create(:groups_user, group: group) }
      let(:user) { groups_user.user }

      it_should_behave_like "the subject's cache is reset when it's request changes" do
        subject { user }
      end
      it_should_behave_like "the subject's cache is reset when it's request changes" do
        subject { group }
      end
    end
  end

  describe '.delayed_auto_accept' do
    let!(:project) { create(:project) }
    let!(:admin) { create(:admin_user) }

    let(:target_package) { create(:package) }
    let(:target_project) { target_package.project }
    let(:source_package) { create(:package) }
    let(:source_project) { source_package.project }

    let!(:request) do
      create(:bs_request_with_submit_action,
             target_project: target_project.name,
             target_package: target_package.name,
             source_project: source_project.name,
             source_package: source_package.name,
             creator: admin.login)
    end

    before do
      allow(BsRequest).to receive(:to_accept).and_return([request])
      allow(BsRequest).to receive(:find).and_return(request)
      allow(request).to receive(:auto_accept)
    end

    subject! { BsRequest.delayed_auto_accept }

    it 'calls auto_accept on the request' do
      expect(request).to have_received(:auto_accept)
    end
  end

  describe '#sanitize!' do
    let(:target_package) { create(:package) }
    let(:patchinfo) { create(:patchinfo) }
    let(:bs_request) { create(:bs_request) }
    let!(:bs_request_action_2) { create(:bs_request_action_add_maintainer_role, bs_request: bs_request, target_project: create(:project)) }

    before do
      login(create(:admin_user))
    end

    context 'when the bs request actions only have lower priorities' do
      before do
        allow(bs_request.bs_request_actions.first).to receive(:minimum_priority).and_return('low')
      end

      it 'does not change the priority of the bs request' do
        expect { bs_request.sanitize! }.not_to(change { HistoryElement::RequestPriorityChange.count })
        expect(bs_request.priority).to eq('moderate')
      end
    end

    context 'when one of the bs request actions has a higher priority' do
      before do
        allow(bs_request.bs_request_actions.first).to receive(:minimum_priority).and_return('important')
        allow(bs_request.bs_request_actions.last).to receive(:minimum_priority).and_return('critical')

        bs_request.sanitize!
      end

      it 'raises the priority of the bs request' do
        expect(bs_request.priority).to eq('critical')
      end

      it 'creates a history element for the priority raise' do
        history_element = HistoryElement::RequestPriorityChange.where(
          comment:               'Automatic priority bump: Priority of related action increased.',
          description_extension: 'moderate => critical'
        )
        expect(history_element).to exist
      end
    end
  end
end
