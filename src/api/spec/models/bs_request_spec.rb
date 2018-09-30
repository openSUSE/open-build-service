require 'rails_helper'
require 'nokogiri'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the BsRequestAction methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe BsRequest, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tux') }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: target_project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:submit_request) do
    create(:bs_request_with_submit_action,
           target_project: target_project.name,
           target_package: target_package.name,
           source_project: source_project.name,
           source_package: source_package.name)
  end
  let(:delete_request) do
    create(:delete_bs_request,
           reviewer: user.login,
           creator:  user.login,
           target_project: target_project.name,
           target_package: target_package.name)
  end

  context 'validations' do
    let(:bs_request) { create(:bs_request) }
    let(:bs_request_action) { create(:bs_request_action, bs_request: bs_request) }

    it 'includes validation errors of associated bs_request_actions' do
      # rubocop:disable Rails/SkipsModelValidations
      bs_request_action.update_attribute(:sourceupdate, 'foo')
      # rubocop:enable Rails/SkipsModelValidations
      expect { bs_request.reload.save! }.to raise_error(
        ActiveRecord::RecordInvalid, 'Validation failed: Bs request actions Sourceupdate is not included in the list'
      )
    end
  end

  context '.new_from_xml' do
    let(:user) { create(:user) }
    let(:review_request) do
      create(:review_bs_request,
             reviewer: user.login,
             target_project: target_package.project.name,
             target_package: target_package.name,
             source_project: source_package.project.name,
             source_package: source_package.name)
    end
    let(:doc) { Nokogiri::XML(review_request.to_axml, &:strict) }

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

    it 'fails with reasonable error' do
      expect { request.addreview(by_user: 'NOEXIST') }.to raise_error do |exception|
        expect(exception).to be_a(BsRequest::InvalidReview)
        expect(exception.message.to_s).to eq('Review invalid: By user NOEXIST not found')
      end
    end
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

    context 'final state declined cannot be changed ' do
      let(:request) do
        create(:declined_bs_request,
               target_package: target_package,
               target_project: target_project,
               source_package: source_package,
               source_project: source_project)
      end

      before do
        User.current = user
      end

      it { expect { request.change_state(newstate: 'review') }.to raise_error(PostRequestNoPermission) }
    end

    context 'final state accepted cannot be changed' do
      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project.name,
               source_project: source_package.project.name,
               source_package: source_package.name)
      end
      let!(:relationship_project_user) { create(:relationship_project_user, project: target_project) }
      let(:user) { relationship_project_user.user }
      before do
        User.current = user
        request.state = 'accepted'
        request.save
      end

      it 'raises and keep accepted state' do
        expect { request.change_state(newstate: 'review') }.to raise_error(PostRequestNoPermission)
        expect(request.state).to eq(:accepted)
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
      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project.name,
               source_project: source_package.project.name,
               source_package: source_package.name)
      end
      let!(:relationship_project_user) { create(:relationship_project_user, project: target_project) }
      let(:user) { relationship_project_user.user }

      it_should_behave_like "the subject's cache is reset when it's request changes"
    end

    context 'group maintainer of a target_project' do
      let(:target_project) { create(:project) }

      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project.name,
               source_project: source_package.project.name,
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
      let!(:request) { submit_request }
      let!(:relationship_package_user) { create(:relationship_package_user, package: target_package) }
      let(:user) { relationship_package_user.user }

      it_should_behave_like "the subject's cache is reset when it's request changes"
    end

    context 'group maintainer of a target_package' do
      let!(:request) { submit_request }
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

  describe '#truncated_diffs?' do
    context "when there is no action with type 'submit'" do
      let(:request_action) do
        {
          'actions' => [
            { type: :foo, sourcediff: ['files' => [['./my_file', { 'diff' => { 'shown' => '200' } }]]] },
            { type: 'bar' }
          ]
        }
      end

      it { expect(BsRequest.truncated_diffs?(request_action)).to eq(false) }
    end

    context 'when there is no sourcediff' do
      let(:request_action) do
        {
          'actions' => [
            { type: :foo, sourcediff: ['files' => [['./my_file', { 'diff' => { 'shown' => '200' } }]]] },
            { type: :submit }
          ]
        }
      end

      it { expect(BsRequest.truncated_diffs?(request_action)).to eq(false) }
    end

    context 'when the sourcediff is empty' do
      let(:request_action) do
        {
          'actions' => [
            { type: :foo, sourcediff: nil },
            { type: :submit }
          ]
        }
      end

      it { expect(BsRequest.truncated_diffs?(request_action)).to eq(false) }
    end

    context 'when the diff is at least one diff that has a shown attribute' do
      let(:request_action) do
        {
          'actions' => [
            { type: :submit, sourcediff: ['files' => [['./my_file', { 'diff' => { 'shown' => '200' } }]]] }
          ]
        }
      end

      it { expect(BsRequest.truncated_diffs?(request_action)).to eq(true) }
    end

    context 'when none of the diffs has a shown attribute' do
      let(:request_action) do
        {
          'actions' => [
            { type: :submit, sourcediff: ['files' => [['./my_file', { 'diff' => { 'rev' => '1' } }]]] }
          ]
        }
      end

      it { expect(BsRequest.truncated_diffs?(request_action)).to eq(false) }
    end

    context "when there is a sourcediff attribute with no 'files'" do
      let(:request_action) do
        {
          'actions' => [
            { type: :submit, sourcediff: ['other_data' => 'foo'] }
          ]
        }
      end

      it { expect(BsRequest.truncated_diffs?(request_action)).to eq(false) }
    end
  end

  context 'auto accept' do
    let!(:project) { create(:project) }
    let!(:admin) { create(:admin_user, login: 'admin') }
    let!(:request) do
      create(:bs_request_with_submit_action,
             target_project: target_package.project.name,
             target_package: target_package.name,
             source_project: source_package.project.name,
             source_package: source_package.name,
             description:    'Update package to newest version',
             creator:        admin.login)
    end

    before do
      request.update(accept_at: 1.hour.ago)
    end

    describe '.delayed_auto_accept' do
      subject! { BsRequest.delayed_auto_accept }

      it { is_expected.to contain_exactly(request) }
      it { expect(request.reload).to have_attributes(state: :accepted, comment: 'Auto accept') }
    end

    describe '#auto_accept' do
      context 'when the request is pending' do
        subject! { request.auto_accept }

        it { expect(request.reload).to have_attributes(state: :accepted, comment: 'Auto accept') }
      end

      context 'when the request was already processed' do
        subject { request.auto_accept }

        before do
          request.update(state: :declined)
          subject
        end

        it { expect(request.reload).not_to have_attributes(state: :accepted, comment: 'Auto accept') }
      end
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

  context '#forward_to' do
    before do
      submit_request.bs_request_actions.first.update(sourceupdate: 'cleanup')
      login user
    end

    it 'only forwards submit requests' do
      delete_request
      expect { delete_request.forward_to(project: user.home_project.name) }.not_to change(BsRequestAction, :count)
    end

    context 'with a project as parameter' do
      subject { submit_request.forward_to(project: user.home_project.name) }

      it 'creates a new submit request open for review' do
        expect(subject).to have_attributes(state: :review, priority: 'moderate')
      end

      it 'creates a submit request action with the correct target' do
        expect(subject.bs_request_actions.count).to eq(1)
        expect(subject.bs_request_actions.where(
                 type:           'submit',
                 target_project: user.home_project.name,
                 target_package: target_package.name,
                 source_project: target_package.project.name,
                 source_package: target_package.name
        )).to exist
      end

      it 'does not set the sourceupdate' do
        expect(subject.bs_request_actions.first.sourceupdate).to be_nil
      end

      it 'sets the logged in user as creator of the request' do
        expect(subject.creator).to eq(user.login)
      end
    end

    context 'with project and package as parameter' do
      subject { submit_request.forward_to(project: user.home_project.name, package: 'my_new_package') }

      it 'creates a submit request action with the correct target' do
        expect(subject.bs_request_actions.count).to eq(1)
        expect(subject.bs_request_actions.where(type: 'submit', target_project: user.home_project.name,
                                                target_package: 'my_new_package')).to exist
      end
    end

    context 'with options' do
      before do
        # For submit requests with 'sourceupdate' the user needs to be able to modify the (forwarded) source package
        target_package.relationships.create(user: user, role: Role.find_by_title!('maintainer'))
      end

      subject do
        submit_request.forward_to(
          project: user.home_project.name,
          options: { description: 'my description' }
        )
      end

      it 'sets the given description' do
        expect(subject).to have_attributes(description: 'my description')
      end

      it 'creates a submit request action with the correct target' do
        expect(subject.bs_request_actions.count).to eq(1)
        expect(subject.bs_request_actions.where(type: 'submit')).to exist
      end
    end
  end

  describe 'creating a BsRequest that has a project link' do
    include_context 'a BsRequest that has a project link'

    context 'via #new' do
      context 'when sourceupdate is not set to cleanup' do
        include_context 'when sourceupdate is set to' do
          let(:sourceupdate_type) { 'cleanup' }
        end

        it { expect { subject.save! }.to raise_error BsRequestAction::LackingMaintainership }
      end

      context 'when sourceupdate is not set to update' do
        include_context 'when sourceupdate is set to' do
          let(:sourceupdate_type) { 'update' }
        end

        it { expect { subject.save! }.to raise_error BsRequestAction::LackingMaintainership }
      end

      context 'when sourceupdate is set to noupdate' do
        include_context 'when sourceupdate is set to' do
          let(:sourceupdate_type) { 'noupdate' }
        end

        it { expect { subject.save! }.not_to raise_error }
      end

      context 'when sourceupdate is not set' do
        include_context 'when sourceupdate is set to' do
          let(:sourceupdate_type) { nil }
        end

        it { expect { subject.save! }.not_to raise_error }
      end
    end

    context 'via #new_from_xml' do
      subject { BsRequest.new_from_xml(xml) }

      it { expect { subject.save! }.to raise_error BsRequestAction::LackingMaintainership }
    end
  end

  describe '::in_state_new' do
    include_context 'a BsRequest with reviews'

    context "when request state is not 'new'" do
      subject { BsRequest.in_state_new(by_user: reviewer.login) }

      it { is_expected.to be_empty }
    end

    context "when request state is 'new'" do
      before do
        bs_request.update(state: 'new')
      end

      it 'queries requests with reviews by user' do
        expect(BsRequest.in_state_new(by_user: reviewer.login)).to contain_exactly(bs_request)
      end

      it 'queries requests with reviews by group' do
        bs_request.reviews.create!(by_group: group.title)
        expect(BsRequest.in_state_new(by_group: group.title)).to contain_exactly(bs_request)
      end

      it 'queries requests with reviews by package' do
        bs_request.reviews.create!(by_package: target_package, by_project: target_project)
        expect(BsRequest.in_state_new(by_package: target_package.name)).to contain_exactly(bs_request)
      end

      it 'queries requests with reviews by target project of bs request' do
        expect(BsRequest.in_state_new(target_project: target_project.name)).to contain_exactly(bs_request)
      end
    end
  end

  describe '::with_open_reviews_for' do
    include_context 'a BsRequest with reviews'

    context "when request state is 'review' but review state is not 'new'" do
      before do
        bs_request.reviews.first.update(state: 'accepted')
      end

      it { expect(BsRequest.with_open_reviews_for(by_user: reviewer.login)).to be_empty }
    end

    context "when request state is 'review' and review state is 'new'" do
      it 'queries requests with reviews by user' do
        expect(BsRequest.with_open_reviews_for(by_user: reviewer.login)).to contain_exactly(bs_request)
      end

      it 'queries requests with reviews by group' do
        bs_request.reviews.create!(by_group: group.title)
        expect(BsRequest.with_open_reviews_for(by_group: group.title)).to contain_exactly(bs_request)
      end

      it 'queries requests with reviews by package' do
        bs_request.reviews.create!(by_package: target_package, by_project: target_project)
        expect(BsRequest.with_open_reviews_for(by_package: target_package.name)).to contain_exactly(bs_request)
      end

      it 'queries requests with reviews by target project of bs request' do
        expect(BsRequest.with_open_reviews_for(target_project: target_project.name)).to contain_exactly(bs_request)
      end
    end
  end

  describe '#as_json' do
    before do
      submit_request.update(superseded_by: delete_request.id)
    end

    subject { submit_request.as_json }

    it 'returns a json representation of a bs request' do
      expect(subject).to include(
        'id' => submit_request.id,
        'number' => submit_request.number,
        'creator' => submit_request.creator,
        'description' => submit_request.description,
        'project' => 'target_project',
        'package' => 'target_package',
        'state' => 'new',
        'request_type' => 'submit',
        'priority' => 'moderate',
        'created_at' => submit_request.created_at,
        'updated_at' => submit_request.updated_at,
        'superseded_by' => delete_request.id,
        'superseded_by_id' => delete_request.id
      )
    end

    context 'when called for a request with a subset of attributes' do
      it { expect { BsRequest.all.select(:id).as_json }.not_to raise_error }
    end
  end
end
