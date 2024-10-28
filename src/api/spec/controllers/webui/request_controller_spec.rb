RSpec.describe Webui::RequestController, :vcr do
  let(:submitter_with_group) { create(:user_with_groups, :with_home, login: 'fluffyrabbit') }
  let(:submitter) { create(:confirmed_user, :with_home, login: 'kugelblitz') }
  let(:receiver) { create(:confirmed_user, :with_home, login: 'titan') }
  let(:reviewer) { create(:confirmed_user, login: 'klasnic') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package_with_file, name: 'goal', project_id: target_project.id) }
  let(:source_project) { submitter.home_project }
  let(:source_project_fluffy) { submitter_with_group.home_project }
  let(:source_package) { create(:package, :as_submission_source, name: 'ball', project: source_project) }
  let(:devel_project) { create(:project, name: 'devel:project') }
  let(:devel_package) { create(:package_with_file, name: 'goal', project: devel_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           description: 'Please take this',
           creator: submitter,
           target_package: target_package,
           source_package: source_package)
  end
  let(:request_with_review) do
    create(:bs_request_with_submit_action,
           review_by_user: reviewer,
           target_package: target_package,
           source_package: source_package)
  end

  it { is_expected.to use_before_action(:require_login) }
  it { is_expected.to use_before_action(:require_request) }

  describe 'GET #show' do
    context 'as nobody' do
      before do
        get :show, params: { number: bs_request.number }
      end

      it 'responds successfully' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns @bs_request' do
        expect(assigns(:bs_request)).to eq(bs_request)
      end
    end

    context 'when there are package maintainers' do
      # The hint will only be shown, when the target package has at least one
      # maintainer. So we'll gonna add a maintainer to the target package.
      let!(:relationship_package_user) { create(:relationship_package_user, user: submitter, package: target_package) }

      before do
        login receiver
        get :show, params: { number: bs_request.number }
      end

      it 'shows a hint to project maintainers' do
        expect(assigns(:show_project_maintainer_hint)).to be_truthy
      end
    end

    context 'when there are no package maintainers' do
      before do
        login receiver
        get :show, params: { number: bs_request.number }
      end

      it 'does not show a hint to project maintainers by default' do
        expect(assigns(:show_project_maintainer_hint)).to be_falsey
      end
    end
  end

  describe 'GET #request_action' do
    before do
      login(submitter)
    end

    context 'handling diff sizes' do
      let(:diff_header_size) { 4 }
      # Taken from package_with_binary_diff factory files (bigfile_archive.tar.gz and bigfile_archive_2.tar.gz)
      let(:archive_content_diff_size) { 12 }
      let(:file_size_threshold) { BsRequestAction::Differ::ForSource::DEFAULT_FILE_LIMIT - 1 }

      before do
        stub_const('BsRequestAction::Differ::ForSource::DEFAULT_FILE_LIMIT', 5)
      end

      shared_examples 'a full diff not requested for' do |file_name|
        before do
          get :request_action, params: { number: bs_request.number, index: 0, id: bs_request.bs_request_actions.first.id, format: :js }, xhr: true
        end

        it 'shows the truncated diff' do
          actions = assigns(:actions).select { |action| action[:type] == :submit && action[:sourcediff] }
          diff_size = actions.first[:sourcediff].first['files'][file_name]['diff']['_content'].split.size
          expect(diff_size).to eq(expected_diff_size)
        end
      end

      context 'full diff not requested' do
        let(:expected_diff_size) { file_size_threshold + diff_header_size }

        context 'for ASCII files' do
          let(:target_package) do
            create(:package_with_file, name: 'test-package-ascii',
                                       file_content: "a\n" * (file_size_threshold + 1), project: target_project)
          end

          it_behaves_like 'a full diff not requested for', 'somefile.txt'
        end

        context 'for archives' do
          let(:target_package) do
            create(:package_with_binary, name: 'test-package-binary', project: target_project)
          end
          let(:source_package) do
            create(:package_with_binary, name: 'test-source-package-binary', project: source_project)
          end

          it_behaves_like 'a full diff not requested for', 'bigfile_archive.tar.gz/bigfile.txt'
        end
      end

      shared_examples 'a full diff requested for' do
        before do
          get :request_action, params: { number: bs_request.number, full_diff: true, index: 0, id: bs_request.bs_request_actions.first.id, format: :js }, xhr: true
        end

        it 'does not show a hint' do
          expect(assigns(:not_full_diff)).to be_falsy
        end
      end

      context 'full diff requested' do
        context 'for ASCII files' do
          let(:expected_diff_size) { file_size_threshold + 1 + diff_header_size }
          let(:target_package) do
            create(:package_with_file, name: 'test-package-ascii',
                                       file_content: "a\n" * (file_size_threshold + 1), project: target_project)
          end

          it_behaves_like 'a full diff requested for'
        end

        context 'for archives' do
          let(:expected_diff_size) { archive_content_diff_size + diff_header_size }
          let(:target_package) { create(:package_with_binary, name: 'test-package-binary', project: target_project) }
          let(:source_package) do
            create(:package_with_binary, name: 'test-source-package-binary', project: source_project, file_name: 'bigfile_archive_2.tar.gz')
          end

          it_behaves_like 'a full diff requested for'
        end
      end

      context 'with :diff_to_superseded set' do
        let(:superseded_bs_request) { create(:set_bugowner_request) }

        context 'and the superseded request is superseded' do
          before do
            superseded_bs_request.update(state: :superseded, superseded_by: bs_request.number)
            get :request_action, params: { number: bs_request.number, diff_to_superseded: superseded_bs_request.number, index: 0,
                                           id: bs_request.bs_request_actions.first.id, format: :js }, xhr: true
          end

          it { expect(assigns(:diff_to_superseded)).to eq(superseded_bs_request) }
        end

        context 'and the superseded request is not superseded' do
          before do
            get :request_action, params: { number: bs_request.number, diff_to_superseded: superseded_bs_request.number, index: 0,
                                           id: bs_request.bs_request_actions.first.id, format: :js }, xhr: true
          end

          it { expect(assigns(:diff_to_superseded)).to be_nil }
          it { expect(flash[:error]).not_to be_nil }
        end
      end
    end
  end

  describe 'POST #modify_review' do
    RSpec.shared_examples 'a valid review' do |new_state|
      subject { request_with_review.reviews.last }

      let(:params_hash) do
        {
          comment: 'yeah',
          review_id: request_with_review.reviews.first
        }
      end
      let(:expected_state) { new_state == 'Approve' ? :accepted : :declined }

      before do
        post :modify_review, params: params_hash.update(new_state: new_state)
        request_with_review.reload
      end

      it { expect(response).to redirect_to(request_show_path(number: request_with_review.number)) }
      it { expect(subject.state).to eq(expected_state) }
      it { expect(flash[:success]).to eq('Successfully submitted review') }
    end

    before do
      login(reviewer)
    end

    context 'with valid parameters' do
      it_behaves_like 'a valid review', 'Approve'
      it_behaves_like 'a valid review', 'Decline'
    end

    context 'with invalid parameters' do
      it 'without request' do
        post :modify_review, params: { comment: 'yeah',
                                       review_id: 1899,
                                       new_state: 'Approve' }
        expect(flash[:error]).to eq('Unable to load request')
        expect(request_with_review.reload.reviews.last.state).to eq(:new)
        expect(request_with_review.reload.state).to eq(:review)
      end

      it 'without state' do
        post :modify_review, params: { comment: 'yeah',
                                       review_id: request_with_review.reviews.first }
        expect(flash[:error]).to eq('Unknown state to set')
        expect(request_with_review.reload.reviews.last.state).to eq(:new)
        expect(request_with_review.reload.state).to eq(:review)
      end

      it 'without permissions' do
        login(submitter)
        post :modify_review, params: { comment: 'yeah',
                                       review_id: request_with_review.reviews.first,
                                       new_state: 'Approve' }
        expect(flash[:error]).to eq("Not permitted to change review state: review state change is not permitted for #{submitter.login}")
        expect(request_with_review.reload.reviews.last.state).to eq(:new)
        expect(request_with_review.reload.state).to eq(:review)
      end

      it 'with invalid transition' do
        request_with_review.update(state: 'declined')
        post :modify_review, params: { comment: 'yeah',
                                       review_id: request_with_review.reviews.first,
                                       new_state: 'Approve' }
        expect(flash[:error]).to eq('Not permitted to change review state: The request is neither in state review nor new')
        expect(request_with_review.reload.state).to eq(:declined)
      end
    end
  end

  describe 'POST #changerequest' do
    context 'with valid parameters' do
      it 'accepts' do
        login(receiver)
        post :changerequest, params: {
          number: bs_request.number, accepted: 'accepted'
        }
        expect(bs_request.reload.state).to eq(:accepted)
      end

      it 'declines' do
        login(receiver)
        post :changerequest, params: {
          number: bs_request.number, declined: 'declined'
        }
        expect(bs_request.reload.state).to eq(:declined)
      end

      it 'revokes' do
        login(submitter)
        post :changerequest, params: {
          number: bs_request.number, revoked: 'revoked'
        }
        expect(bs_request.reload.state).to eq(:revoked)
      end

      it 'adds submitter as maintainer' do
        login(receiver)
        post :changerequest, params: {
          number: bs_request.number, accepted: 'accepted',
          add_submitter_as_maintainer_0: "#{target_project}_#_#{target_package}" # rubocop:disable Naming/VariableNumber
        }
        expect(bs_request.reload.state).to eq(:accepted)
        expect(target_package.relationships.map(&:user_id)).to include(submitter.id)
      end

      it 'forwards' do
        login(receiver)
        bs_request
        expect do
          post :changerequest, params: { number: bs_request.number, accepted: 'accepted',
                                         forward_devel_0: "#{devel_package.project}_#_#{devel_package}", # rubocop:disable Naming/VariableNumber
                                         description: 'blah blah blah' }
        end.to change(BsRequest, :count).by(1)
        expect(BsRequest.last.bs_request_actions).to eq(devel_package.project.target_of_bs_request_actions)
      end
    end

    context 'when forwarding the request fails' do
      before do
        allow(BsRequestActionSubmit).to receive(:new).and_raise(APIError, 'some error')
        bs_request
        login(receiver)
      end

      it 'accepts the parent request and reports an error for the forwarded request' do
        expect do
          post :changerequest, params: { number: bs_request.number, accepted: 'accepted',
                                         forward_devel_0: "#{devel_package.project}_#_#{devel_package}", # rubocop:disable Naming/VariableNumber
                                         description: 'blah blah blah' }
        end.not_to change(BsRequest, :count)
        expect(bs_request.reload.state).to eq(:accepted)
        expect(flash[:success]).to match('Request \\d accepted')
        expect(flash[:error]).to eq('Unable to forward submit request: some error')
      end
    end
  end

  describe 'POST #set_bugowner_request' do
    let(:bs_request) { BsRequest.find_by(creator: submitter_with_group.login, description: 'blah blah blash', state: 'new') }

    context 'with valid parameters' do
      before do
        login(submitter_with_group)
        post :set_bugowner_request, params: {
          project: source_project_fluffy.name,
          user: submitter_with_group.login,
          group: submitter_with_group.groups.first.title,
          description: 'blah blah blash'
        }
      end

      it { expect(bs_request).not_to be_nil }
      it { expect(bs_request.description).to eq('blah blah blash') }
      it { expect(response).to redirect_to(request_show_path(number: bs_request)) }
    end
  end

  describe 'POST #sourcediff' do
    context 'with xhr header' do
      before do
        post :sourcediff, xhr: true
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response).to render_template('shared/_editor') }
    end

    context 'without xhr header' do
      let(:call_sourcediff) { post :sourcediff }

      it { expect { call_sourcediff }.to raise_error(ActionController::RoutingError, 'Expected AJAX call') }
    end
  end
end
