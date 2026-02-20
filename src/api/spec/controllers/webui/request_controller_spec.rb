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
      let!(:relationship_package_user) do
        receiver.run_as do
          create(:relationship_package_user, user: submitter, package: target_package)
        end
      end

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
            create(:package_with_binary, name: 'test-source-package-binary', project: source_project, file_name: 'spec/fixtures/files/bigfile_archive_2.tar.gz')
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
      # TODO: Check no maintainer has been made and no forwarding happens
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

      context 'when using the beta request show page' do
        context 'and sending a submit request from a source package to an existing target package' do
          it 'accepts the request and adds the submitter a maintainer when clicking the right dropdown button' do
            login(receiver)
            post :changerequest, params: {
              number: bs_request.number, accepted: 'Accept and make maintainer'
            }
            expect(bs_request.reload.state).to eq(:accepted)
            expect(target_package.relationships.map(&:user_id)).to include(submitter.id)
          end

          it 'accepts the request and forwards it when clicking the right dropdown button' do
            login(receiver)
            devel_package.update!(develpackage: bs_request.bs_request_actions.first.target_package_object)
            expect do
              post :changerequest, params: { number: bs_request.number, accepted: 'Accept and forward',
                                             description: 'blah blah blah' }
            end.to change(BsRequest, :count).by(1)
            expect(BsRequest.last.bs_request_actions).to eq(devel_package.project.target_of_bs_request_actions)
          end

          it 'accepts the request, forwards it and make the submitter a maintainer' do
            login(receiver)
            devel_package.update!(develpackage: bs_request.bs_request_actions.first.target_package_object)
            post :changerequest, params: {
              number: bs_request.number, accepted: 'Accept, make maintainer and forward'
            }
            expect(bs_request.reload.state).to eq(:accepted)
            expect(target_package.relationships.map(&:user_id)).to include(submitter.id)
            expect(BsRequest.last.bs_request_actions).to eq(devel_package.project.target_of_bs_request_actions)
          end
        end

        context 'and sending a submit request from a new package' do
          subject! do
            login(receiver)
            post :changerequest, params: {
              number: bs_request.number, accepted: button_label
            }
          end

          let(:bs_request) do
            create(:bs_request_with_submit_action,
                   description: 'Please take this',
                   creator: submitter,
                   target_project: target_project,
                   target_package: source_package.name,
                   source_package: source_package)
          end
          let(:target_package) { Package.find_by_project_and_name(target_project.name, source_package.name) }

          context 'and clicking on the accept and make maintainer button' do
            let(:button_label) { 'Accept and make maintainer' }

            it 'accepts the request' do
              expect(bs_request.reload.state).to eq(:accepted)
            end

            it 'makes the creator a maintainer on the target package' do
              expect(target_package.maintainers.map(&:login)).to include(bs_request.creator)
            end
          end

          context 'and clicking on the accept only button' do
            let(:button_label) { 'Accept' }

            it 'accepts the request' do
              expect(bs_request.reload.state).to eq(:accepted)
            end

            it 'makes no more maintainers' do
              expect(target_package.maintainers.map(&:login)).not_to include(bs_request.creator)
            end
          end
        end

        context 'and sending a request with mixed actions' do
          subject! do
            login(receiver)
            post :changerequest, params: {
              number: bs_request.number, accepted: button_label
            }
          end

          before do
            login(submitter)
            create(:bs_request_action_set_bugowner,
                   bs_request: bs_request,
                   target_project: target_project,
                   target_package: target_package)
          end

          context 'and clicking on the accept and make maintainer button' do
            let(:button_label) { 'Accept and make maintainer' }

            it 'accepts the request' do
              expect(bs_request.reload.state).to eq(:accepted)
            end

            it 'makes the creator a maintainer on the target package' do
              expect(target_package.maintainers.map(&:login)).to include(bs_request.creator)
            end
          end

          context 'and clicking on the accept only button' do
            let(:button_label) { 'Accept' }

            it 'accepts the request' do
              expect(bs_request.reload.state).to eq(:accepted)
            end

            it 'makes no more maintainers' do
              expect(target_package.maintainers.map(&:login)).not_to include(bs_request.creator)
            end
          end
        end

        context 'and sending a request without submit actions' do
          subject! do
            create(:bs_request_action_set_bugowner,
                   bs_request: bs_request,
                   target_project: target_project,
                   target_package: target_package)
            login(receiver)
            post :changerequest, params: {
              number: bs_request.number, accepted: button_label
            }
          end

          let(:bs_request) do
            login(submitter)
            create(:add_role_request,
                   creator: submitter,
                   role: 'bugowner',
                   target_project: target_project,
                   target_package: target_package)
          end

          context 'and clicking on the accept and make maintainer button' do
            let(:button_label) { 'Accept and make maintainer' }

            it 'accepts the request' do
              expect(bs_request.reload.state).to eq(:accepted)
            end

            it 'makes no more maintainers' do
              expect(target_package.maintainers.map(&:login)).not_to include(bs_request.creator)
            end
          end

          context 'and clicking on the accept only button' do
            let(:button_label) { 'Accept' }

            it 'accepts the request' do
              expect(bs_request.reload.state).to eq(:accepted)
            end

            it 'makes no more maintainers' do
              expect(target_package.maintainers.map(&:login)).not_to include(bs_request.creator)
            end
          end
        end

        context 'and sending a request with a submit action that can be forwarded and another that cannot' do
          context 'and clicking on the accept, make maintainer and forward button' do
            subject! do
              login(receiver)
              devel_package.update!(develpackage: bs_request.bs_request_actions.first.target_package_object)
              post :changerequest, params: {
                number: bs_request.number, accepted: 'Accept, make maintainer and forward'
              }
            end

            let(:another_target_package) { create(:package, name: 'another_target_package') }
            let(:another_target_project) { another_target_package.project }

            before do
              login(submitter)
              create(:bs_request_action_submit,
                     bs_request: bs_request,
                     source_project: source_project,
                     source_package: source_package,
                     target_package: another_target_package,
                     target_project: another_target_project)
            end

            it 'accepts the request' do
              expect(bs_request.reload.state).to eq(:accepted)
            end

            it 'makes the creator a maintainer on the target package' do
              expect(target_package.relationships.map(&:user_id)).to include(submitter.id)
            end

            it 'forwards the action that can be forwarded' do
              expect(BsRequestAction.where(source_project: target_project.name,
                                           source_package: target_package.name,
                                           target_project: devel_package.project.name,
                                           target_package: devel_package.name).count).to be 1
            end

            it 'does not forward the action that cannot be forwarded' do
              expect(BsRequestAction.where(source_project: another_target_project.name,
                                           source_package: another_target_package.name,
                                           target_project: devel_package.project.name,
                                           target_package: devel_package.name).count).to be 0
            end
          end

          context 'and clicking on the accept and forward button' do
            subject! do
              login(submitter)
              devel_package.update!(develpackage: bs_request.bs_request_actions.first.target_package_object)
              login(receiver)
              post :changerequest, params: {
                number: bs_request.number, accepted: 'Accept and forward'
              }
            end

            let(:another_target_package) { create(:package, name: 'another_target_package') }
            let(:another_target_project) { another_target_package.project }
            let(:bs_request) do
              create(:bs_request_with_submit_action,
                     description: 'Please take this',
                     creator: submitter,
                     target_package: target_package,
                     source_package: source_package)
            end

            before do
              create(:bs_request_action_submit,
                     bs_request: bs_request,
                     source_project: source_project,
                     source_package: source_package,
                     target_package: another_target_package,
                     target_project: target_project)
            end

            it 'accepts the request' do
              expect(bs_request.reload.state).to eq(:accepted)
            end

            it 'does not make the creator a maintainer on the target package' do
              expect(target_package.relationships.map(&:user_id)).not_to(include(submitter.id))
            end

            it 'forwards the action that can be forwarded' do
              expect(BsRequestAction.where(source_project: target_project.name,
                                           source_package: target_package.name,
                                           target_project: devel_package.project.name,
                                           target_package: devel_package.name).count).to be 1
            end

            it 'does not forward the action that cannot be forwarded' do
              expect(BsRequestAction.where(source_project: another_target_project.name,
                                           source_package: another_target_package.name,
                                           target_project: devel_package.project.name,
                                           target_package: devel_package.name).count).to be 0
            end
          end

          context 'and clicking on the accept only button' do
            subject do
              login(receiver)
              devel_package.update!(develpackage: bs_request.bs_request_actions.first.target_package_object)
              post :changerequest, params: {
                number: bs_request.number, accepted: 'Accept'
              }
              bs_request.reload.state
            end

            let(:another_target_package) { create(:package, name: 'another_target_package') }
            let(:another_target_project) { another_target_package.project }

            before do
              submitter.run_as do
                create(:bs_request_action_submit,
                       bs_request: bs_request,
                       source_project: source_project,
                       source_package: source_package,
                       target_package: another_target_package,
                       target_project: target_project)
              end
            end

            it 'accepts the request' do
              expect(subject).to eq(:accepted)
            end

            it 'makes no more maintainers' do
              expect { subject }.not_to change(Relationship, :count)
            end

            it 'does not forward anything' do
              expect { subject }.not_to change(BsRequest, :count)
            end
          end
        end
      end
    end

    context 'when forwarding the request fails' do
      before do
        allow(BsRequestActionSubmit).to receive(:new).and_raise(APIError, 'some error')
        login(receiver)
        bs_request
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

  describe 'POST #add_reviewer' do
    context 'when request does not exist' do
      before do
        login(receiver)
        post :add_reviewer, params: { number: 0, review_type: 'review-user', review_user: reviewer.login }
      end

      it { expect(flash[:error]).to eq("Unable to add review to request with id '0': the request was not found.") }
    end

    context 'when the user does not have permission to add reviewers' do
      let(:uninvolved_user) { create(:confirmed_user, login: 'foo') }

      before do
        login(uninvolved_user)
        post :add_reviewer, params: { number: bs_request.number, review_type: 'review-user', review_user: reviewer.login }
      end

      it { expect(flash[:error]).to eq("Not permitted to add a review to '#{bs_request.number}'") }
      it { expect(bs_request.reload.state).to eq(:new) }
      it { expect(response).to redirect_to(request_show_path(number: bs_request)) }
    end

    context 'when the review is not valid' do
      before do
        login(receiver)
        post :add_reviewer, params: { number: bs_request.number, review_type: 'review-user', review_user: 'DOES_NOT_EXIST' }
      end

      it { expect(flash[:error]).to eq("Unable to add review to request with id '#{bs_request.number}': Review invalid: User can't be blank") }
      it { expect(bs_request.reload.state).to eq(:new) }
      it { expect(response).to redirect_to(request_show_path(number: bs_request)) }
    end
  end

  describe 'GET #changes', :beta do
    let(:action) { bs_request.bs_request_actions.first }

    before do
      login(submitter)
      allow(BsRequest).to receive(:find_by!).and_return(bs_request)
      allow(bs_request.bs_request_actions).to receive(:find).and_return(action)
      allow(action).to receive_messages(webui_sourcediff: [], diff_not_cached: false)
    end

    it 'responds successfully' do
      get :changes, params: { number: bs_request.number }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:changes)
    end

    it 'assigns @active_tab' do
      get :changes, params: { number: bs_request.number }
      expect(assigns(:active_tab)).to eq('changes')
    end

    it 'supports full_diff parameter' do
      allow(action).to receive(:diff_not_cached).with(hash_including(tarlimit: 0)).and_return(false)
      get :changes, params: {
        number: bs_request.number,
        full_diff: 'true'
      }
      expect(response).to have_http_status(:success)
      expect(action).to have_received(:diff_not_cached).with(hash_including(tarlimit: 0))
    end

    it 'queues a job when diff is not cached' do
      allow(action).to receive(:diff_not_cached).and_return(true)
      allow(BsRequestActionWebuiInfosJob).to receive(:perform_later)
      get :changes, params: { number: bs_request.number }
      expect(response).to have_http_status(:success)
      expect(BsRequestActionWebuiInfosJob).to have_received(:perform_later)
    end
  end

  describe 'GET #changes_diff', :beta do
    let(:action) { bs_request.bs_request_actions.first }

    before do
      login(submitter)
      allow(BsRequest).to receive(:find_by!).and_return(bs_request)
      allow(bs_request.bs_request_actions).to receive(:find).and_return(action)
      allow(action).to receive_messages(webui_sourcediff: [{ 'files' => {}, 'new' => {}, 'old' => {} }],
                                        diff_not_cached: false, source_package_object: nil, target_package_object: nil)
    end

    it 'responds successfully' do
      get :changes_diff, params: { number: bs_request.number, request_action_id: bs_request.bs_request_actions.first.id, filename: 'foo', format: :html }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(partial: 'webui/request/_changes_diff')
    end
  end

  describe 'GET #request_action_changes', :beta do
    let(:action) { bs_request.bs_request_actions.first }

    before do
      login(submitter)
      allow(BsRequest).to receive(:find_by!).and_return(bs_request)
      allow(bs_request.bs_request_actions).to receive(:find).and_return(action)
      allow(action).to receive_messages(webui_sourcediff: [], diff_not_cached: false)
    end

    it 'responds successfully' do
      get :request_action_changes, params: { number: bs_request.number, request_action_id: bs_request.bs_request_actions.first.id }, xhr: true
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:request_action_changes)
    end

    it 'supports full_diff parameter' do
      allow(action).to receive(:diff_not_cached).with(hash_including(tarlimit: 0)).and_return(false)
      get :request_action_changes, params: {
        number: bs_request.number,
        request_action_id: action.id,
        full_diff: 'true'
      }, xhr: true
      expect(response).to have_http_status(:success)
      expect(action).to have_received(:diff_not_cached).with(hash_including(tarlimit: 0))
    end
  end
end
