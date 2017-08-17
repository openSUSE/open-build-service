require 'rails_helper'

RSpec.describe CommentsController, type: :controller do
  render_views
  describe 'GET #show' do
    let(:user) { create(:confirmed_user) }

    RSpec.shared_examples 'request comment index' do
      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:obj)).to eq(comment.commentable) }
      it {
        expect(response.body).
          to include("<comment who=\"#{comment.user}\" when=\"#{comment.created_at}\" id=\"#{comment.id}\">#{comment.body}</comment>")
      }
    end

    context 'of a project' do
      let(:comment) { create(:comment_project) }
      let(:project) { comment.commentable }

      before do
        login user
        get :index, format: :xml, params: { project: project }
      end

      include_examples 'request comment index'
      it { expect(response.body).to include("<comments project=\"#{project.name}\">") }
    end

    context 'of a package' do
      let(:comment) { create(:comment_package) }
      let(:package) { comment.commentable }

      before do
        login user
        get :index, format: :xml, params: { package: package, project: package.project }
      end

      include_examples 'request comment index'
      it { expect(response.body).to include("<comments project=\"#{package.project.name}\" package=\"#{package.name}\">") }
    end

    context 'of a bs_request' do
      let(:comment) { create(:comment_request) }
      let(:bs_request) { comment.commentable }

      before do
        login user
        get :index, format: :xml, params: { id: bs_request.number }
      end

      include_examples 'request comment index'
      it { expect(response.body).to include("<comments request=\"#{bs_request.number}\">") }
    end
  end
end
