RSpec.describe BsRequest, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tux') }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: target_project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:submit_request) do
    create(:bs_request_with_submit_action,
           target_package: target_package,
           source_package: source_package)
  end
  let(:delete_request) do
    create(:delete_bs_request,
           reviewer: user,
           creator: user,
           target_package: target_package)
  end

  context 'validations' do
    let(:bs_request) { create(:set_bugowner_request) }
    let(:bs_request_action) { bs_request.bs_request_actions.first }

    it 'includes validation errors of associated bs_request_actions' do
      # rubocop:disable Rails/SkipsModelValidations
      bs_request_action.update_attribute(:sourceupdate, 'foo')
      # rubocop:enable Rails/SkipsModelValidations
      expect { bs_request.reload.save! }.to raise_error(
        ActiveRecord::RecordInvalid, 'Validation failed: Bs request actions Sourceupdate is not included in the list'
      )
    end
  end

  describe '.new_from_xml' do
    let(:user) { create(:user, :with_home) }
    let(:review_request) do
      create(:bs_request_with_submit_action,
             review_by_user: user,
             target_package: target_package,
             source_package: source_package)
    end
    let(:doc) { Nokogiri::XML(review_request.to_axml, &:strict) }
    let(:output) { BsRequest.new_from_xml(doc.to_xml) }

    context "'when' attribute provided" do
      let!(:updated_when) { 10.years.ago }

      before do
        doc.at_css('state')['when'] = updated_when
      end

      # We don't care about milliseconds, therefore we parse to integer
      it { expect(output.updated_when.to_i).to eq(updated_when.to_i) }
    end

    context "'when' attribute not provided" do
      before do
        doc.xpath('//@when').remove
      end

      # We don't care about milliseconds, therefore we parse to integer
      it { expect(output.updated_when.to_i).to eq(output.updated_at.to_i) }
    end
  end

  describe '#assignreview' do
    context 'from group to user' do
      let(:reviewer) { create(:confirmed_user) }
      let(:new_review) { request.reviews.last }
      let(:group) { create(:group) }
      let!(:request) { create(:set_bugowner_request, creator: reviewer, review_by_group: group) }
      let(:review) { request.reviews.first }

      before do
        login(reviewer)

        request.assignreview(by_group: group.title, reviewer: reviewer.login)
      end

      it { expect(request.reviews.count).to eq(2) }

      it 'creates a new review by the user' do
        expect(new_review.by_user).to eq(reviewer.login)
        expect(new_review.history_elements.last.type).to eq('HistoryElement::ReviewAssigned')
      end

      it 'updates the old review state to accepted and assigns it' do
        expect(review.reload.state).to eq(:accepted)
        expect(review.review_assigned_to).to eq(request.reviews.last)
        expect(review.reviewer).to eq(reviewer.login)
        expect(review.history_elements.last.type).to eq('HistoryElement::ReviewAccepted')
      end
    end
  end

  describe '#addreview' do
    subject { Review.last }

    let(:reviewer) { create(:confirmed_user) }
    let(:history_element) { HistoryElement::RequestReviewAdded.last }
    let(:group) { create(:group) }
    let!(:request) { create(:set_bugowner_request, creator: reviewer) }

    before do
      login(reviewer)
      request.addreview(by_group: group.title)
    end

    it { expect(subject.state).to eq(:new) }
    it { expect(subject.by_group).to eq(group.title) }
    it { expect(subject.reviewer).to eq(reviewer.login) }
    it { expect(subject.creator).to eq(reviewer.login) }

    it { expect(history_element.request).to eq(request) }
    it { expect(history_element.user).to eq(reviewer) }

    it { expect(request.state).to eq(:review) }
    it { expect(request.commenter).to eq(reviewer.login) }

    it 'fails with not found' do
      expect { request.addreview(by_user: 'NOEXIST') }.to raise_error do |exception|
        expect(exception).to be_a(NotFoundError)
        expect(exception.message).to eq('User not found')
      end
    end
  end

  describe '#change_review_state' do
    let(:user) { create(:confirmed_user) }
    let!(:request) { create(:set_bugowner_request, creator: user) }
    let(:reviewer) { create(:confirmed_user) }
    let(:someone) { create(:confirmed_user) }

    context 'with by_user review' do
      before do
        login user
        request.addreview(by_user: reviewer, comment: 'does it look ok?')
      end

      it 'raises exception on missing by_ paramter' do
        expect { request.change_review_state(:accepted) }.to raise_error(BsRequest::InvalidReview)
      end

      it 'raises exception on wrong user' do
        expect { request.change_review_state(:accepted, by_user: someone.login) }.to raise_error(Review::NotFoundError)
        expect(request.state).to be(:review)
      end

      context 'with the proper reviewer' do
        subject { request.change_review_state(:accepted, by_user: reviewer.login) }

        it 'moves to new' do
          expect { subject }.not_to raise_error
          expect(request.state).to be(:new)
        end

        it 'sends 3 events', rabbitmq: '#' do
          empty_message_queue
          subject

          body = expect_message('opensuse.obs.request.review_changed')
          expect(body).to include('author' => user.login)

          body = expect_message('opensuse.obs.request.reviews_done')
          expect(body).to include('author' => user.login, 'state' => 'new', 'comment' => 'All reviewers accepted request', 'number' => request.number)

          expect_message('opensuse.obs.metrics', "request.reviews_done,state=new number=#{request.number}")

          expect_no_message
        end

        it 'allows multiple reviews by user' do
          request.addreview(by_user: reviewer, comment: 'does it still look ok?')
          request.change_review_state(:accepted, by_user: reviewer.login)
          # one of the reviews is accepted, but the other stays open
          expect(request.state).to be(:review)
          request.change_review_state(:accepted, by_user: reviewer.login)
          expect(request.state).to be(:new)
        end
      end
    end
  end

  describe '#changestate' do
    let!(:request) { create(:set_bugowner_request) }
    let(:admin) { create(:admin_user) }

    context 'to delete state' do
      before do
        login admin
        request.change_state(newstate: 'deleted')
      end

      it 'changes state to deleted' do
        expect(request.state).to eq(:deleted)
      end

      it 'creates a HistoryElement::RequestDeleted' do
        expect(request.history_elements.first.type).to eq('HistoryElement::RequestDeleted')
      end
    end

    context 'final state declined cannot be changed' do
      let(:request) do
        create(:declined_bs_request,
               target_package: target_package,
               source_package: source_package)
      end

      before do
        login user
      end

      it { expect { request.change_state(newstate: 'review') }.to raise_error(PostRequestNoPermission) }
    end

    context 'when the request is accepted' do
      let(:creator) { create(:confirmed_user, login: 'sagan') }
      let(:source_project) { create(:project, name: 'source_project_123', maintainer: creator) }
      let(:source_package) { create(:package, project: source_project, name: 'source_package_123') }
      let(:target_project) { create(:project, name: 'project_123', maintainer: creator) }
      let(:target_package) { create(:package, project: target_project, name: 'package_123') }
      let!(:request) do
        create(:bs_request_with_submit_action, source_project: source_project, source_package: source_package, target_project: target_project, target_package: target_package,
                                               creator: creator, description: 'A single comment')
      end

      context 'and the target project has an attribute to disallow acceptance by the creator' do
        context 'and the accepter is the creator' do
          before do
            login creator

            # Attach the attribute to the target project so to trigger the validation
            attrib_type = AttribType.find_by_namespace_and_name!('OBS', 'CreatorCannotAcceptOwnRequests')
            a = Attrib.create!(attrib_type: attrib_type, project: target_project)
            a.values.create(value: '1')
          end

          it 'triggers an error' do
            expect { request.change_state(newstate: 'accepted', force: true) }.to raise_error(BsRequest::Errors::CreatorCannotAcceptOwnRequests)
          end
        end

        context 'and the accepter is NOT the creator' do
          let(:user) { create(:confirmed_user, login: 'clarke') }

          before do
            # Make the user be part of the staff of the project, so we can send requests to it
            create(:relationship_project_user, project: target_project, user: user)

            login user

            # Attach the attribute to the target project so to trigger the validation
            attrib_type = AttribType.find_by_namespace_and_name!('OBS', 'CreatorCannotAcceptOwnRequests')
            a = Attrib.create!(attrib_type: attrib_type, project: target_project)
            a.values.create(value: '1')
          end

          it 'accepts the request' do
            request.change_state(newstate: 'accepted', force: true)
            expect(request.state).to be(:accepted)
          end
        end
      end

      context 'and the target package has an attribute to disallow acceptance by the creator' do
        context 'and the accepter is the creator' do
          before do
            login creator

            # Attach the attribute to the target project so to trigger the validation
            attrib_type = AttribType.find_by_namespace_and_name!('OBS', 'CreatorCannotAcceptOwnRequests')
            a = Attrib.create!(attrib_type: attrib_type, package: target_package)
            a.values.create(value: '1')
          end

          it 'triggers an error' do
            expect { request.change_state(newstate: 'accepted') }.to raise_error(BsRequest::Errors::CreatorCannotAcceptOwnRequests)
          end
        end

        context 'and the accepter is NOT the creator' do
          let(:user) { create(:confirmed_user, login: 'bujold') }

          before do
            login user

            # Attach the attribute to the target project so to trigger the validation
            attrib_type = AttribType.find_by_namespace_and_name!('OBS', 'CreatorCannotAcceptOwnRequests')
            a = Attrib.create!(attrib_type: attrib_type, package: target_package)
            a.values.create(value: '1')

            # Make the user be part of the staff of the project, so we can send requests to it
            create(:relationship_project_user, project: target_project, user: user)
          end

          it 'accepts the request' do
            request.change_state(newstate: 'accepted', force: true)

            expect(request.state).to be(:accepted)
          end
        end
      end
    end

    context 'final state accepted cannot be changed' do
      let!(:request) do
        create(:bs_request_with_submit_action,
               target_project: target_project,
               source_package: source_package)
      end
      let!(:relationship_project_user) { create(:relationship_project_user, project: target_project) }
      let(:user) { relationship_project_user.user }

      before do
        login user
        request.state = 'accepted'
        request.save
      end

      it 'raises and keep accepted state' do
        expect { request.change_state(newstate: 'review') }.to raise_error(PostRequestNoPermission)
        expect(request.state).to eq(:accepted)
      end
    end

    context 'when bs_request is staged' do
      let(:project) { user.home_project }
      let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
      let(:group) { staging_workflow.managers_group }
      let(:staging_project) { staging_workflow.staging_projects.first }
      let(:target_package) { create(:package, name: 'target_package', project: project) }
      let(:source_project) { create(:project, name: 'source_project') }
      let(:source_package) { create(:package, name: 'source_package', project: source_project) }
      let(:bs_request) do
        request = create(:bs_request_with_submit_action,
                         state: :review,
                         creator: admin,
                         target_package: target_package,
                         source_package: source_package,
                         review_by_project: staging_project.name,
                         staging_owner: admin)
        request.staging_project = staging_project
        request.save
        request
      end

      before do
        login user
        staging_workflow
        bs_request.change_review_state(:accepted, by_group: group.title, comment: 'accepted')
      end

      it { expect(bs_request.staging_project).to be_present }

      context 'when a staged bs_request is accepted', :vcr do
        let(:backend_response) do
          <<~XML
            <revision rev="12" vrev="12">
              <srcmd5>d41d8cd98f00b204e9800998ecf8427e</srcmd5>
              <version>unknown</version>
              <time>1578926184</time>
              <user>user_4</user>
              <comment>fake comment.</comment>
              <requestid>2</requestid>
              <acceptinfo rev="12" srcmd5="d41d8cd98f00b204e9800998ecf8427e" osrcmd5="d41d8cd98f00b204e9800998ecf8427e"/>
            </revision>
          XML
        end

        before do
          allow(Backend::Api::Sources::Package).to receive(:copy).and_return(backend_response)
          bs_request.change_review_state(:accepted, by_project: staging_project.name, comment: 'accepted')
          bs_request.change_state(newstate: 'accepted')
        end

        it { expect(bs_request.staging_project).to be_nil }
      end
    end
  end

  describe '#truncated_diffs?' do
    context "when there is no action with type 'submit'" do
      let(:request_actions) do
        [
          { type: :foo, sourcediff: [{ 'files' => [['./my_file', { 'diff' => { 'shown' => '200' } }]] }] },
          { type: 'bar' }
        ]
      end

      it { expect(BsRequest.truncated_diffs?(request_actions)).to be(false) }
    end

    context 'when there is no sourcediff' do
      let(:request_actions) do
        [
          { type: :foo, sourcediff: [{ 'files' => [['./my_file', { 'diff' => { 'shown' => '200' } }]] }] },
          { type: :submit }
        ]
      end

      it { expect(BsRequest.truncated_diffs?(request_actions)).to be(false) }
    end

    context 'when the sourcediff is empty' do
      let(:request_actions) do
        [
          { type: :foo, sourcediff: nil },
          { type: :submit }
        ]
      end

      it { expect(BsRequest.truncated_diffs?(request_actions)).to be(false) }
    end

    context 'when the diff is at least one diff that has a shown attribute' do
      let(:request_actions) do
        [{ type: :submit, sourcediff: [{ 'files' => [['./my_file', { 'diff' => { 'shown' => '200' } }]] }] }]
      end

      it { expect(BsRequest.truncated_diffs?(request_actions)).to be(true) }
    end

    context 'when none of the diffs has a shown attribute' do
      let(:request_actions) do
        [{ type: :submit, sourcediff: [{ 'files' => [['./my_file', { 'diff' => { 'rev' => '1' } }]] }] }]
      end

      it { expect(BsRequest.truncated_diffs?(request_actions)).to be(false) }
    end

    context "when there is a sourcediff attribute with no 'files'" do
      let(:request_actions) do
        [{ type: :submit, sourcediff: [{ 'other_data' => 'foo' }] }]
      end

      it { expect(BsRequest.truncated_diffs?(request_actions)).to be(false) }
    end
  end

  context 'auto accept' do
    let!(:project) { create(:project) }
    let!(:user) { create(:confirmed_user, login: 'tux') }
    let!(:maintainer_role) { create(:relationship, package: target_package, user: user) }
    let!(:request) do
      create(:bs_request_with_submit_action,
             target_package: target_package,
             source_package: source_package,
             description: 'Update package to newest version',
             creator: user)
    end

    before do
      request.update(accept_at: 1.hour.ago)
    end

    describe '.delayed_auto_accept', :vcr do
      subject! { BsRequest.delayed_auto_accept }

      it { is_expected.to contain_exactly(request) }
      it { expect(request.reload).to have_attributes(state: :accepted, comment: 'Auto accept') }
    end

    describe '#auto_accept' do
      context 'when the request is pending', :vcr do
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

      context "when creator doesn't have permissions for the target project", :vcr do
        subject { request.auto_accept }

        before do
          maintainer_role.delete
          subject
        end

        it { expect(request.reload).to have_attributes(comment: 'Permission problem', state: :revoked) }
      end
    end
  end

  describe '#sanitize!' do
    let(:target_package) { create(:package) }
    let(:patchinfo) { create(:patchinfo) }
    let(:bs_request) { create(:add_maintainer_request, target_project: create(:project)) }

    before do
      login(create(:admin_user))
      create(:bs_request_action_add_maintainer_role, bs_request: bs_request, target_project: create(:project))
    end

    context 'when the bs request actions only have lower priorities' do
      before do
        allow(bs_request.bs_request_actions.first).to receive(:minimum_priority).and_return('low')
      end

      it 'does not change the priority of the bs request' do
        expect { bs_request.sanitize! }.not_to(change(HistoryElement::RequestPriorityChange, :count))
        expect(bs_request.priority).to eq('moderate')
      end
    end

    context 'when one of the bs request actions has a higher priority' do
      before do
        bs_request.bs_request_actions.reload
        allow(bs_request.bs_request_actions.first).to receive(:minimum_priority).and_return('important')
        allow(bs_request.bs_request_actions.last).to receive(:minimum_priority).and_return('critical')

        bs_request.sanitize!
      end

      it 'raises the priority of the bs request' do
        expect(bs_request.priority).to eq('critical')
      end

      it 'creates a history element for the priority raise' do
        history_element = HistoryElement::RequestPriorityChange.where(
          comment: 'Automatic priority bump: Priority of related action increased.',
          description_extension: 'moderate => critical'
        )
        expect(history_element).to exist
      end
    end
  end

  describe '#forward_to', :vcr do
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
                 type: 'submit',
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
        expect(subject.bs_request_actions.where(type: 'submit', target_project:  user.home_project.name,
                                                target_package: 'my_new_package')).to exist
      end
    end

    context 'with options' do
      subject do
        submit_request.forward_to(
          project: user.home_project.name,
          options: { description: 'my description' }
        )
      end

      before do
        login(user)
        # For submit requests with 'sourceupdate' the user needs to be able to modify the (forwarded) source package
        target_package.relationships.create(user: user, role: Role.find_by_title!('maintainer'))
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
      context 'when sourceupdate is not set to cleanup', :vcr do
        include_context 'when sourceupdate is set to' do
          let(:sourceupdate_type) { 'cleanup' }
        end

        it { expect { subject.save! }.to raise_error BsRequestAction::LackingMaintainership }
      end

      context 'when sourceupdate is not set to update', :vcr do
        include_context 'when sourceupdate is set to' do
          let(:sourceupdate_type) { 'update' }
        end

        it { expect { subject.save! }.to raise_error BsRequestAction::LackingMaintainership }
      end

      context 'when sourceupdate is set to noupdate', :vcr do
        include_context 'when sourceupdate is set to' do
          let(:sourceupdate_type) { 'noupdate' }
        end

        it { expect { subject.save! }.not_to raise_error }
      end

      context 'when sourceupdate is not set', :vcr do
        include_context 'when sourceupdate is set to' do
          let(:sourceupdate_type) { nil }
        end

        it { expect { subject.save! }.not_to raise_error }
      end
    end

    context 'via #new_from_xml', :vcr do
      subject { BsRequest.new_from_xml(xml) }

      it { expect { subject.save! }.to raise_error BsRequestAction::LackingMaintainership }
    end
  end

  describe '#as_json' do
    subject { submit_request.as_json }

    before do
      submit_request.update(superseded_by: delete_request.id)
    end

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
        'created_at' => submit_request.created_at.as_json,
        'updated_at' => submit_request.updated_at.as_json,
        'superseded_by' => delete_request.id,
        'superseded_by_id' => delete_request.id
      )
    end

    context 'when called for a request with a subset of attributes' do
      it { expect { BsRequest.select(:id).as_json }.not_to raise_error }
    end
  end

  describe '#skip_sanitize' do
    let(:bs_request) { build(:add_maintainer_request, target_project: create(:project)) }

    before do
      bs_request.skip_sanitize
      allow(bs_request).to receive(:sanitize!)
      User.find_by!(login: bs_request.creator).run_as do
        bs_request.save!
      end
    end

    it { expect(bs_request).not_to have_received(:sanitize!) }
  end

  describe '#action_details' do
    context 'when diffs are cached' do
      let!(:request) { submit_request }
      let!(:opts) { { filelimit: nil, tarlimit: nil, diff_to_superseded: nil, diffs: true, cacheonly: 1 } }

      it 'sets the value for diff_not_cached' do
        action_details = request.send(:action_details, opts, xml: request.bs_request_actions.last)
        expect(action_details[:diff_not_cached]).to be(false)
      end
    end
  end
end
