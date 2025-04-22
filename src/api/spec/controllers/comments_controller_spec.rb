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
      let(:comment) { create(:comment, commentable: object, diff_file_index: 0, diff_line_number: 1) }

      before do
        login user
        comment
      end

      context 'with an inline comment' do
        before do
          get :index, format: :xml, params: { request_number: object.bs_request.number }
        end

        it { expect(response.body).to include('Inline comment for target:').and(include(comment.body)) }
      end

      context 'with an inline comment of a removed target package' do
        before do
          object.target_package_object.destroy

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
