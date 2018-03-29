require 'rails_helper'
# WARNING: If you change changerequest tests make sure you uncomment this line
# and start a test backend. Some of the methods require real backend answers
# for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::RequestController, vcr: true do
  let(:submitter) { create(:confirmed_user, login: 'kugelblitz') }
  let(:receiver) { create(:confirmed_user, login: 'titan') }
  let(:reviewer) { create(:confirmed_user, login: 'klasnic') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package_with_file, name: 'goal', project_id: target_project.id) }
  let(:source_project) { submitter.home_project }
  let(:source_package) { create(:package, name: 'ball', project_id: source_project.id) }
  let(:devel_project) { create(:project, name: 'devel:project') }
  let(:devel_package) { create(:package, name: 'goal', project: devel_project) }
  let(:bs_request) { create(:bs_request, description: 'Please take this', creator: submitter.login) }
  let(:bs_request_submit_action) do
    create(:bs_request_action_submit, target_project: target_project.name,
                                      target_package: target_package.name,
                                      source_project: source_project.name,
                                      source_package: source_package.name,
                                      bs_request_id: bs_request.id)
  end
  let(:request_with_review) do
    create(:review_bs_request,
           reviewer: reviewer,
           target_project: target_project.name,
           target_package: target_package.name,
           source_project: source_project.name,
           source_package: source_package.name)
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

    context 'if request does not exist' do
      before do
        get :show, params: { number: '200000' }
      end

      it { expect(flash[:error]).to eq("Can't find request 200000") }
      it { expect(response).to redirect_to(user_show_path(User.current)) }
    end

    context 'when there are package maintainers' do
      # The hint will only be shown, when the target package has at least one
      # maintainer. So we'll gonna add a maintainer to the target package.
      let!(:relationship_package_user) { create(:relationship_package_user, user: submitter, package: target_package) }

      before do
        login receiver
        bs_request.bs_request_actions.delete_all
        bs_request_submit_action
        get :show, params: { number: bs_request.number }
      end

      it 'shows a hint to project maintainers' do
        expect(assigns(:show_project_maintainer_hint)).to be_truthy
      end
    end

    context 'when there are no package maintainers' do
      before do
        login receiver
        bs_request_submit_action
        get :show, params: { number: bs_request.number }
      end

      it 'does not show a hint to project maintainers by default' do
        expect(assigns(:show_project_maintainer_hint)).to be_falsey
      end
    end

    context 'handling diff sizes' do
      let(:diff_header_size) { 4 }
      let(:ascii_file_size) { 11_000 }
      # Taken from package_with_binary_diff factory files (bigfile_archive.tar.gz and bigfile_archive_2.tar.gz)
      let(:binary_file_size) { 30_000 }
      let(:binary_file_changed_size) { 13_000 }
      # TODO: check if this value, the default diff size, is correct
      let(:default_diff_size) { 9999 }

      shared_examples 'a full diff not requested for' do |file_name|
        before do
          bs_request_submit_action
          get :show, params: { number: bs_request.number }
        end

        it 'shows a hint' do
          expect(assigns(:not_full_diff)).to be_truthy
        end

        it 'shows the truncated diff' do
          actions = assigns(:actions).select { |action| action[:type] == :submit && action[:sourcediff] }
          diff_size = actions.first[:sourcediff].first['files'][file_name]['diff']['_content'].split.size
          expect(diff_size).to eq(expected_diff_size)
        end
      end

      context 'full diff not requested' do
        let(:expected_diff_size) { default_diff_size + diff_header_size }
        context 'for ASCII files' do
          let(:target_package) do
            create(:package_with_file, name: 'test-package-ascii',
                   file_content: "a\n" * ascii_file_size, project: target_project)
          end

          it_behaves_like 'a full diff not requested for', 'somefile.txt'
        end

        context 'for archives' do
          let(:target_package) do
            create(:package_with_binary, name: 'test-package-binary', project: target_project)
          end
          let(:source_package) do
            create(:package_with_binary, name: 'test-source-package-binary', project: source_project,
                   file_name: 'spec/support/files/bigfile_archive_2.tar.gz')
          end

          it_behaves_like 'a full diff not requested for', 'bigfile_archive.tar.gz/bigfile.txt'
        end
      end

      shared_examples 'a full diff requested for' do |file_name|
        before do
          bs_request_submit_action
          get :show, params: { number: bs_request.number, full_diff: true }
        end

        it 'does not show a hint' do
          expect(assigns(:not_full_diff)).to be_falsy
        end

        it 'shows the complete diff' do
          actions = assigns(:actions).select { |action| action[:type] == :submit && action[:sourcediff] }
          diff_size = actions.first[:sourcediff].first['files'][file_name]['diff']['_content'].split.size
          expect(diff_size).to eq(expected_diff_size)
        end
      end

      context 'full diff requested' do
        context 'for ASCII files' do
          let(:expected_diff_size) { ascii_file_size + diff_header_size }
          let(:target_package) do
            create(:package_with_file, name: 'test-package-ascii',
                   file_content: "a\n" * ascii_file_size, project: target_project)
          end

          it_behaves_like 'a full diff requested for', 'somefile.txt'
        end

        context 'for archives' do
          let(:expected_diff_size) { binary_file_size + binary_file_changed_size + diff_header_size }
          let(:target_package) { create(:package_with_binary, name: 'test-package-binary', project: target_project) }
          let(:source_package) do
            create(:package_with_binary, name: 'test-source-package-binary',
                   project: source_project, file_name: 'spec/support/files/bigfile_archive_2.tar.gz')
          end

          it_behaves_like 'a full diff requested for', 'bigfile_archive.tar.gz/bigfile.txt'
        end
      end

      context 'with :diff_to_superseded set' do
        let(:superseded_bs_request) { create(:bs_request) }
        context 'and the superseded request is superseded' do
          before do
            superseded_bs_request.update(state: :superseded, superseded_by: bs_request.number)
            get :show, params: { number: bs_request.number, diff_to_superseded: superseded_bs_request.number }
          end

          it { expect(assigns(:diff_to_superseded)).to eq(superseded_bs_request) }
        end

        context 'and the superseded request is not superseded' do
          before do
            get :show, params: { number: bs_request.number, diff_to_superseded: superseded_bs_request.number }
          end

          it { expect(assigns(:diff_to_superseded)).to be_nil }
          it { expect(flash[:error]).not_to be_nil }
        end
      end
    end
  end

  describe 'POST #delete_request' do
    before do
      login(submitter)
    end

    context 'a valid request' do
      before do
        post :delete_request, params: { project: target_project, package: target_package, description: 'delete it!' }
      end

      subject do
        BsRequest.joins(:bs_request_actions).
          where('bs_request_actions.target_project=? AND bs_request_actions.target_package=? AND type=?',
                target_project.to_s, target_package.to_s, 'delete').first
      end

      it { expect(response).to redirect_to(request_show_path(number: subject)) }
      it { expect(flash[:success]).to match("Created .+repository delete request #{subject.number}") }
      it { expect(subject.description).to eq('delete it!') }
    end

    context 'a request causing a APIException' do
      before do
        allow_any_instance_of(BsRequest).to receive(:save!).and_raise(APIException, 'something happened')
        post :delete_request, params: { project: target_project, package: target_package, description: 'delete it!' }
      end

      it { expect(flash[:error]).to eq('something happened') }
      it { expect(response).to redirect_to(package_show_path(project: target_project, package: target_package)) }

      it 'does not create a delete request' do
        expect(BsRequest.count).to eq(0)
      end
    end
  end

  describe 'POST #modify_review' do
    RSpec.shared_examples 'a valid review' do |new_state|
      let(:params_hash) do
        {
          review_comment_0:        'yeah',
          review_request_number_0: request_with_review.number,
          review_by_user_0:        reviewer
        }
      end

      before do
        subject.update(state: 'declined') if new_state == 'new'

        params_hash[new_state.to_sym] = 'non-important string'
        post :modify_review, params: params_hash
      end

      subject { request_with_review.reload.reviews.last }

      it { expect(response).to redirect_to(request_show_path(number: request_with_review.number)) }
      it { expect(subject.state).to eq(new_state) }
      it { expect(flash[:success]).to eq('Successfully submitted review') }
    end

    before do
      login(reviewer)
    end

    context 'with valid parameters' do
      it_behaves_like 'a valid review', :accepted
      it_behaves_like 'a valid review', :new
      it_behaves_like 'a valid review', :declined
    end

    context 'with invalid parameters' do
      it 'without request' do
        post :modify_review, params: { review_comment_0:        'yeah',
                                       review_request_number_0: 1899,
                                       review_by_user_0:        reviewer,
                                       accepted:                'Approve' }
        expect(flash[:error]).to eq('Unable to load request')
        expect(request_with_review.reload.reviews.last.state).to eq(:new)
        expect(request_with_review.reload.state).to eq(:review)
      end

      it 'without state' do
        post :modify_review, params: { review_comment_0:        'yeah',
                                       review_request_number_0: request_with_review.number,
                                       review_by_user_0:        reviewer }
        expect(flash[:error]).to eq('Unknown state to set')
        expect(request_with_review.reload.reviews.last.state).to eq(:new)
        expect(request_with_review.reload.state).to eq(:review)
      end

      it 'without permissions' do
        post :modify_review, params: { review_comment_0:        'yeah',
                                       review_request_number_0: request_with_review.number,
                                       review_by_user_0:        submitter,
                                       accepted:                'Approve' }
        expect(flash[:error]).to eq("Not permitted to change review state: review state change is not permitted for #{reviewer.login}")
        expect(request_with_review.reload.reviews.last.state).to eq(:new)
        expect(request_with_review.reload.state).to eq(:review)
      end

      it 'with invalid transition' do
        request_with_review.update_attributes(state: 'declined')
        post :modify_review, params: { review_comment_0:        'yeah',
                                       review_request_number_0: request_with_review.number,
                                       review_by_user_0:        reviewer,
                                       accepted:                'Approve' }
        expect(flash[:error]).to eq('Not permitted to change review state: The request is neither in state review nor new')
        expect(request_with_review.reload.state).to eq(:declined)
      end
    end
  end

  describe 'POST #changerequest' do
    before do
      bs_request.bs_request_actions.delete_all
      bs_request_submit_action
    end

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
          number: bs_request.number, accepted: 'accepted', add_submitter_as_maintainer_0: "#{target_project}_#_#{target_package}"
        }
        expect(bs_request.reload.state).to eq(:accepted)
        expect(target_package.relationships.map(&:user_id).include?(submitter.id)).to be_truthy
      end

      it 'forwards' do
        login(receiver)
        expect do
          post :changerequest, params: { number: bs_request.number, accepted: 'accepted',
                                         forward_devel_0: "#{devel_package.project}_#_#{devel_package}",
                                         description: 'blah blah blah' }
        end.to change { BsRequest.count }.by(1)
        expect(BsRequest.last.bs_request_actions).to eq(devel_package.project.target_of_bs_request_actions)
      end
    end

    context 'with invalid parameters' do
      before do
        login(receiver)
        post :changerequest, params: { number: 1899, accepted: 'accepted' }
      end

      it 'without request' do
        expect(flash[:error]).to eq('Can\'t find request 1899')
      end
    end

    context 'when forwarding the request fails' do
      before do
        allow(BsRequestActionSubmit).to receive(:new).and_raise(APIException, 'some error')
        login(receiver)
      end

      it 'accepts the parent request and reports an error for the forwarded request' do
        expect do
          post :changerequest, params: { number: bs_request.number, accepted: 'accepted',
                                         forward_devel_0: "#{devel_package.project}_#_#{devel_package}",
                                         description: 'blah blah blah' }
        end.not_to change(BsRequest, :count)
        expect(bs_request.reload.state).to eq(:accepted)
        expect(flash[:notice]).to match('Request \\d accepted')
        expect(flash[:error]).to eq('Unable to forward submit request: some error')
      end
    end
  end

  describe 'POST #change_devel_request' do
    context 'with valid parameters' do
      before do
        login(submitter)
        post :change_devel_request, params: {
          project: target_project.name, package: target_package.name,
            devel_project: source_project.name, devel_package: source_package.name, description: 'change it!'
        }
        @bs_request = BsRequest.where(description: 'change it!', creator: submitter.login, state: 'new').first
      end

      it { expect(response).to redirect_to(request_show_path(number: @bs_request)) }
      it { expect(flash[:success]).to be nil }
      it { expect(@bs_request).not_to be nil }
      it { expect(@bs_request.description).to eq('change it!') }

      it 'creates a request action with correct data' do
        request_action = @bs_request.bs_request_actions.where(
          type: 'change_devel',
          target_project: target_project.name,
          target_package: target_package.name,
          source_project: source_project.name,
          source_package: source_package.name
        )
        expect(request_action).to exist
      end
    end

    context 'with invalid devel_package parameter' do
      before do
        login(submitter)
        post :change_devel_request, params: {
          project: target_project.name, package: target_package.name,
            devel_project: source_project.name, devel_package: 'non-existant', description: 'change it!'
        }
        @bs_request = BsRequest.where(description: 'change it!', creator: submitter.login, state: 'new').first
      end

      it { expect(flash[:error]).to eq("No such package: #{source_project.name}/non-existant") }
      it { expect(response).to redirect_to(package_show_path(project: target_project, package: target_package)) }
      it { expect(@bs_request).to be nil }
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
