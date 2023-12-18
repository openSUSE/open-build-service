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
end
