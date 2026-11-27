RSpec.describe CommentsController do
  render_views
  describe 'GET #show' do
    let(:user) { create(:confirmed_user) }

    RSpec.shared_examples 'request comment index' do
      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:obj)).to eq(object) }

      it {
        expect(response.body)
          .to include("<comment who=\"#{comment.user}\" when=\"#{comment.created_at}\" id=\"#{comment.id}\">#{comment.body}</comment>")
      }
    end

    context 'of a project' do
      let(:comment) { create(:comment_project) }
      let(:object) { comment.commentable }

      before do
        login user
        get :index, format: :xml, params: { project: object }
      end

      it_behaves_like 'request comment index'
      it { expect(response.body).to include("<comments project=\"#{object.name}\">") }
    end

    context 'of a package' do
      let(:comment) { create(:comment_package) }
      let(:object) { comment.commentable }

      before do
        login user
        get :index, format: :xml, params: { package: object, project: object.project.name }
      end

      it_behaves_like 'request comment index'
      it { expect(response.body).to include("<comments project=\"#{object.project.name}\" package=\"#{object.name}\">") }
    end

    context 'of a bs_request' do
      let(:comment) { create(:comment_request) }
      let(:object) { comment.commentable }

      before do
        login user
        get :index, format: :xml, params: { request_number: object.number }
      end

      it_behaves_like 'request comment index'
      it { expect(response.body).to include("<comments request=\"#{object.number}\">") }
    end

    context 'of a bs_request_action (inline comment)', :vcr do
      let(:submit_request) { create(:bs_request_with_submit_action) }
      let(:object) { create(:bs_request_action_submit_with_diff, bs_request: submit_request) }
      let!(:comment) { create(:comment, commentable: object, diff_file_index: 0, diff_line_number: 1) }

      before do
        login user
      end

      context 'with an inline comment' do
        before do
          get :index, format: :xml, params: { request_number: object.bs_request.number }
        end

        it { expect(response.body).to include('Inline comment for target:').and(include(comment.body)) }
      end

      context 'with an inline comment of a removed target package' do
        before do
          User.find_by!(login: object.bs_request.creator).run_as do
            Package.find_by_project_and_name(object.target_project, object.target_package)
          end

          get :index, format: :xml, params: { request_number: object.bs_request.number }
        end

        it { expect(response.body).to include("<comment who=\"#{comment.user}\" when=\"#{comment.created_at}\" id=\"#{comment.id}\">#{comment.body}</comment>") }
      end
    end

    context 'of a user' do
      let!(:comment) { create(:comment_request, user: user) }
      let(:object) { user }

      before do
        login user
        get :index, format: :xml
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:obj)).to eq(object) }

      it {
        expect(response.body)
          .to include("<comment who=\"#{comment.user}\" when=\"#{comment.created_at}\" id=\"#{comment.id}\" bsrequest=\"#{comment.commentable.number}\">#{comment.body}</comment>")
      }

      it { expect(response.body).to include("<comments user=\"#{user.login}\">") }
    end
  end

  describe 'POST #create' do
    let(:user) { create(:confirmed_user) }

    before do
      login user
    end

    context 'when commenting on a BsRequest' do
      let(:bs_request) { create(:set_bugowner_request) }

      before do
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something' }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'when replying to a comment on a BsRequest' do
      let(:bs_request) { create(:set_bugowner_request) }
      let(:parent_comment) { create(:comment_request, commentable: bs_request) }

      before do
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something', parent_id: parent_comment.id }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'when replying to a comment on a BsRequestAction' do
      let(:bs_request) { create(:set_bugowner_request) }
      let(:bs_request_action) { bs_request.bs_request_actions.first }
      let(:parent_comment) { create(:comment_request, commentable: bs_request_action) }

      before do
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something', parent_id: parent_comment.id }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'when creating a diff comment on a BsRequestAction' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let(:bs_request_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }
      let(:comment) { bs_request_action.comments.last }

      before do
        allow(Backend::Api::Sources::Package).to receive(:files) do |project, _package, _opts|
          "<directory srcmd5=\"#{project}_md5\" />"
        end
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              target_project: bs_request_action.target_project,
                                              target_package: bs_request_action.target_package,
                                              diff_file_index: 0, diff_line_number: 1 }
      end

      it { expect(response).to have_http_status(:success) }

      it 'creates the comment with the body and diff file index' do
        expect(comment.body).to include('Something')
        expect(comment.diff_file_index).to eq(0)
      end

      it 'creates the comment with the diff line number and source rev from the action' do
        expect(comment.diff_line_number).to eq(1)
        expect(comment.source_rev).to eq('source_project_md5')
      end

      it 'creates the comment with the target rev from the action' do
        expect(comment.target_rev).to eq('target_project_md5')
      end
    end

    context 'when creating a diff comment by filename' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let(:bs_request_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }
      let(:comment) { bs_request_action.comments.last }

      before do
        allow(Backend::Api::Sources::Package).to receive(:files) do |project, _package, _opts|
          "<directory srcmd5=\"#{project}_md5\" />"
        end
        sourcediff_xml = <<~XML
          <sourcediff key='test'>
            <old project='source_project' package='source_package' rev='1' srcmd5='source_project_md5' />
            <new project='target_project' package='target_package' rev='1' srcmd5='target_project_md5' />
            <files>
              <file state='changed'>
                <old name='aaa.txt' md5='aaaa' size='42' />
                <new name='aaa.txt' md5='bbbb' size='10' />
                <diff lines='1'># diff</diff>
              </file>
              <file state='changed'>
                <old name='bbb.txt' md5='cccc' size='42' />
                <new name='bbb.txt' md5='dddd' size='10' />
                <diff lines='1'># diff</diff>
              </file>
            </files>
            <issues>
            </issues>
          </sourcediff>
        XML
        allow(Backend::Api::Sources::Package).to receive(:source_diff).and_return(sourcediff_xml)
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              target_project: bs_request_action.target_project,
                                              target_package: bs_request_action.target_package,
                                              filename: 'bbb.txt', diff_line_number: 1 }
      end

      it { expect(response).to have_http_status(:success) }

      it 'creates the comment with the file index resolved from the filename' do
        expect(comment.diff_file_index).to eq(1)
        expect(comment.diff_line_number).to eq(1)
      end
    end

    context 'when the filename is not in the request diff' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let(:bs_request_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }

      before do
        allow(Backend::Api::Sources::Package).to receive(:files) do |project, _package, _opts|
          "<directory srcmd5=\"#{project}_md5\" />"
        end
        sourcediff_xml = <<~XML
          <sourcediff key='test'>
            <old project='source_project' package='source_package' rev='1' srcmd5='source_project_md5' />
            <new project='target_project' package='target_package' rev='1' srcmd5='target_project_md5' />
            <files>
              <file state='changed'>
                <old name='aaa.txt' md5='aaaa' size='42' />
                <new name='aaa.txt' md5='bbbb' size='10' />
                <diff lines='1'># diff</diff>
              </file>
            </files>
            <issues>
            </issues>
          </sourcediff>
        XML
        allow(Backend::Api::Sources::Package).to receive(:source_diff).and_return(sourcediff_xml)
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              target_project: bs_request_action.target_project,
                                              target_package: bs_request_action.target_package,
                                              filename: 'missing.txt', diff_line_number: 1 }
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'when the caller passes source_rev and target_rev' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let(:bs_request_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }
      let(:comment) { bs_request_action.comments.last }

      before do
        allow(Backend::Api::Sources::Package).to receive(:files) do |project, _package, _opts|
          "<directory srcmd5=\"#{project}_md5\" />"
        end
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              target_project: bs_request_action.target_project,
                                              target_package: bs_request_action.target_package,
                                              diff_file_index: 0, diff_line_number: 1,
                                              source_rev: 'caller_source_md5', target_rev: 'caller_target_md5' }
      end

      it { expect(response).to have_http_status(:success) }

      it 'creates the comment with the caller-provided revs' do
        expect(comment.source_rev).to eq('caller_source_md5')
        expect(comment.target_rev).to eq('caller_target_md5')
      end
    end

    context 'when commenting on a request action without diff information' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let(:bs_request_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }
      let(:comment) { bs_request_action.comments.last }

      before do
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              target_project: bs_request_action.target_project,
                                              target_package: bs_request_action.target_package }
      end

      it { expect(response).to have_http_status(:success) }

      it 'creates a plain comment on the action, without a diff file index' do
        expect(comment.diff_file_index).to be_nil
        expect(comment.diff_line_number).to be_nil
      end

      it 'creates a plain comment on the action, without diff revisions' do
        expect(comment.source_rev).to be_nil
        expect(comment.target_rev).to be_nil
      end
    end

    context 'when no request action matches the target' do
      let(:bs_request) { create(:bs_request_with_submit_action) }

      before do
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              target_project: 'nonexistent_project', target_package: 'nonexistent_package',
                                              diff_file_index: 0, diff_line_number: 1 }
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'when multiple request actions match the target' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let!(:first_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }
      let!(:second_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }

      before do
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              target_project: first_action.target_project,
                                              target_package: first_action.target_package,
                                              diff_file_index: 0, diff_line_number: 1 }
      end

      it { expect(response).to have_http_status(:unprocessable_content) }
    end

    context 'when the caller passes action_id' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let!(:first_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }
      let!(:second_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }
      let(:comment) { second_action.comments.last }

      before do
        allow(Backend::Api::Sources::Package).to receive(:files) do |project, _package, _opts|
          "<directory srcmd5=\"#{project}_md5\" />"
        end
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              action_id: second_action.id,
                                              diff_file_index: 0, diff_line_number: 1 }
      end

      it { expect(response).to have_http_status(:success) }

      it 'creates the comment on the action named by id' do
        expect(comment.body).to include('Something')
        expect(comment.commentable).to eq(second_action)
      end
    end

    context 'when the action_id names no action of the request' do
      let(:bs_request) { create(:bs_request_with_submit_action) }

      before do
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              action_id: 99_999,
                                              diff_file_index: 0, diff_line_number: 1 }
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'when the request has a single action and no target is given' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let(:bs_request_action) { bs_request.bs_request_actions.first }
      let(:comment) { bs_request_action.comments.last }

      before do
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              diff_file_index: 0, diff_line_number: 1 }
      end

      it { expect(response).to have_http_status(:success) }

      it 'creates the comment on the single request action' do
        expect(comment.body).to include('Something')
        expect(comment.commentable).to eq(bs_request_action)
      end

      it 'creates the comment with the diff file index and line number' do
        expect(comment.diff_file_index).to eq(0)
        expect(comment.diff_line_number).to eq(1)
      end
    end

    context 'when multiple request actions exist and no target is given' do
      let(:bs_request) { create(:bs_request_with_submit_action) }
      let!(:first_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }
      let!(:second_action) { create(:bs_request_action_submit_with_diff, bs_request: bs_request) }

      before do
        post :create, format: :xml, params: { request_number: bs_request.number, body: 'Something',
                                              diff_file_index: 0, diff_line_number: 1 }
      end

      it { expect(response).to have_http_status(:unprocessable_content) }
    end
  end

  describe 'GET #history' do
    let(:moderator) { create(:moderator) }
    let(:comment) { create(:comment_project) }

    before do
      with_versioning do
        comment.update!(body: 'I edited this comment!')
      end

      login(moderator)

      Flipper.enable(:content_moderation)
      get :history, format: :xml, params: { id: comment.id }
    end

    it { expect(response.body).to include("<comment_history comment=\"#{comment.id}\">") }

    it {
      expect(response.body).to include("<comment who=\"#{comment.paper_trail.previous_version.user}\" when=\"#{comment.paper_trail.previous_version.created_at}\" " \
                                       "id=\"#{comment.id}\">#{comment.paper_trail.previous_version.body}</comment>")
    }
  end
end
