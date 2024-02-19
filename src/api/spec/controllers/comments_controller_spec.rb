RSpec.describe CommentsController do
  render_views
  describe 'GET #index' do
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

      include_examples 'request comment index'
      it { expect(response.body).to include("<comments project=\"#{object.name}\">") }
    end

    context 'of a package' do
      let(:comment) { create(:comment_package) }
      let(:object) { comment.commentable }

      before do
        login user
        get :index, format: :xml, params: { package: object, project: object.project.name }
      end

      include_examples 'request comment index'
      it { expect(response.body).to include("<comments project=\"#{object.project.name}\" package=\"#{object.name}\">") }
    end

    context 'of a bs_request' do
      let(:comment) { create(:comment_request) }
      let(:object) { comment.commentable }

      before do
        login user
        get :index, format: :xml, params: { request_number: object.number }
      end

      include_examples 'request comment index'
      it { expect(response.body).to include("<comments request=\"#{object.number}\">") }
    end

    context 'of a bs_request_action (inline comment)', :vcr do
      let(:submit_request) { create(:bs_request_with_submit_action) }
      let(:object) { create(:bs_request_action_submit_with_diff, bs_request: submit_request) }
      let(:comment) { create(:comment, commentable: object, diff_ref: 'diff_0_n1') }

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

  describe 'GET #show' do
    let(:user) { create(:confirmed_user) }

    RSpec.shared_examples 'request comment show' do
      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:comment)).to eq(comment) }

      it {
        expect(response.body.strip)
          .to eq("<comment who=\"#{comment.user}\" when=\"#{comment.created_at}\" id=\"#{comment.id}\">#{comment.body}</comment>")
      }
    end

    context 'of a project' do
      let(:comment) { create(:comment_project) }

      before do
        login user
        get :show, format: :xml, params: { id: comment.id }
      end

      include_examples 'request comment show'
    end

    context 'of a package' do
      let(:comment) { create(:comment_package) }

      before do
        login user
        get :show, format: :xml, params: { id: comment.id }
      end

      include_examples 'request comment show'
    end

    context 'of a bs_request' do
      let(:comment) { create(:comment_request) }

      before do
        login user
        get :show, format: :xml, params: { id: comment.id }
      end

      include_examples 'request comment show'
    end
  end

  describe 'PUT #update' do
    let(:user) { create(:confirmed_user) }
    let(:new_comment_body) { 'new comment body' }

    before do
      login user
    end

    context 'of a project' do
      let(:comment) { create(:comment_project, user: user) }

      before do
        put :update, format: :xml, params: { id: comment.id, body: new_comment_body }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'of a package' do
      let(:comment) { create(:comment_package, user: user) }

      before do
        put :update, format: :xml, params: { id: comment.id, body: new_comment_body }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'of a bs_request' do
      let(:comment) { create(:comment_request, user: user) }

      before do
        put :update, format: :xml, params: { id: comment.id, body: new_comment_body }
      end

      it { expect(response).to have_http_status(:success) }
    end
  end
end
