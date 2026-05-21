RSpec.describe Webui::CommentsController do
  let(:user) { create(:confirmed_user, login: 'luck') }

  before do
    login user
  end

  describe 'POST #create' do
    let(:project) { create(:project) }
    let(:package) { create(:package, project: project) }
    let(:bs_request) { create(:set_bugowner_request) }

    context 'with invalid commentable_type' do
      subject! { post :create, params: comment_params }

      let(:comment_params) do
        { comment: { body: 'This is AWESOME!' }, commentable_type: 'FOOBAR', commentable_id: 31_337 }
      end

      it 'fails to create a comment' do
        expect(flash[:error]).to eq('Invalid commentable FOOBAR supplied.')
      end
    end

    context 'with a valid comment' do
      subject! { post :create, params: comment_params }

      RSpec.shared_examples 'saving a comment' do
        let(:comment_params) do
          { comment: { body: "This #{commentable.model_name.singular} is AWESOME!" },
            commentable_type: commentable.class, commentable_id: commentable.id }
        end

        it { expect(flash[:success]).to eq('Comment created successfully.') }
        it { expect(commentable.comments.first.body).to eq("This #{commentable.model_name.singular} is AWESOME!") }
      end

      context 'of a project' do
        let(:commentable) { project }

        it_behaves_like 'saving a comment'
      end

      context 'of a package' do
        let(:commentable) { package }

        it_behaves_like 'saving a comment'
      end

      context 'of a bs_request' do
        let(:commentable) { bs_request }

        it_behaves_like 'saving a comment'
      end
    end

    context 'with a commentable that does not exist' do
      subject! { post :create, params: comment_params }

      context 'of a project' do
        let(:commentable) { project }
        let(:comment_params) do
          { comment: { body: 'This project is AWESOME!' },
            commentable_type: commentable.class, commentable_id: -commentable.id }
        end

        it { expect(flash[:error]).to eq('Failed to create comment: This project does not exist anymore.') }
        it { expect(package.comments.count).to eq(0) }
      end

      context 'of a package' do
        let(:commentable) { package }
        let(:comment_params) do
          { comment: { body: 'This package is AWESOME!' },
            commentable_type: commentable.class, commentable_id: -commentable.id }
        end

        it { expect(flash[:error]).to eq('Failed to create comment: This package does not exist anymore.') }
        it { expect(package.comments.count).to eq(0) }
      end

      context 'of a bs_request' do
        let(:commentable) { bs_request }
        let(:comment_params) do
          { comment: { body: 'This bs_request is AWESOME!' },
            commentable_type: commentable.class, commentable_id: -commentable.id }
        end

        it { expect(flash[:error]).to eq('Failed to create comment: This bsrequest does not exist anymore.') }
        it { expect(package.comments.count).to eq(0) }
      end
    end

    context 'saving a comment without body' do
      subject! { post :create, params: comment_params }

      let(:comment_params) do
        { comment: { body: '' }, commentable_type: package.class, commentable_id: package.id }
      end

      it { expect(flash[:error]).to eq("Failed to create comment: Body can't be blank.") }
      it { expect(package.comments.count).to eq(0) }
    end

    context "does not allow to overwrite the comment's user" do
      subject { post :create, params: comment_params }

      let(:comment_params) { { comment: { body: 'This project is AWESOME!', user_id: user }, commentable_type: project.class, commentable_id: project.id } }

      it 'raises an error' do
        expect { subject }.to raise_error(ActionController::UnpermittedParameters)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:admin) { create(:admin_user, login: 'Admin') }
    let(:comment) { create(:comment_project, user: user) }
    let(:other_comment) { create(:comment_project) }

    context 'can destroy own comments' do
      before do
        delete :destroy, params: { id: comment.id }
      end

      it { expect(flash[:success]).to eq('Comment deleted successfully.') }
      it { expect(Comment.where(id: comment.id)).to eq([]) }
    end

    context 'cannot destroy comment of somebody else' do
      before do
        delete :destroy, params: { id: other_comment.id }
      end

      it { expect(flash[:success]).to be_nil }
      it { expect(Comment.where(id: comment.id)).to eq([comment]) }
    end

    context 'admin can destroy comments not owned by him' do
      before do
        login admin
        delete :destroy, params: { id: other_comment.id }
      end

      it { expect(flash[:success]).to eq('Comment deleted successfully.') }
      it { expect(Comment.where(id: other_comment.id)).to eq([]) }
    end

    context 'whith the request_show_redesign beta flag active' do
      render_views

      before { Flipper.enable(:request_show_redesign, admin) }

      let!(:root_comment) { create(:comment_request, body: 'This is a root comment') }

      context 'deleting a root comment' do
        context 'with no replies' do
          before do
            login admin
            delete :destroy, params: { id: root_comment.id }
          end

          it 'removes the comment thread from the view' do
            expect(response.body).to be_empty
          end
        end

        context 'and having a reply' do
          let(:commentable) { root_comment.commentable }
          let!(:root_reply) { create(:comment_request, commentable: commentable, body: 'This is a reply', parent_id: root_comment.id) }

          before do
            login admin
            delete :destroy, params: { id: root_comment.id }
          end

          it 'renders This comment has been deleted' do
            expect(response.body).to have_text('This comment has been deleted')
          end

          it 'renders the replies below' do
            expect(response.body).to have_no_text('This is a root comment')
            expect(response.body).to have_text('This is a reply')
          end
        end
      end

      context 'deleting a reply' do
        context 'with no replies' do
          let!(:leaf) { create(:comment_request, commentable: root_comment.commentable, body: 'This is a leaf comment', parent_id: root_comment.id) }

          before do
            login admin
            delete :destroy, params: { id: leaf.id }
          end

          it 'renders the updated thread without the reply' do
            expect(response.body).to have_text('This is a root comment')
          end

          it 'removes the reply from the view' do
            expect(response.body).to have_no_text('This is a leaf')
          end
        end

        context 'with replies' do
          let(:reply) { create(:comment_request, commentable: root_comment.commentable, body: 'This is a reply comment', parent_id: root_comment.id) }
          let!(:leaf) { create(:comment_request, commentable: root_comment.commentable, body: 'This is a leaf comment', parent_id: reply.id) }

          before do
            login admin
            delete :destroy, params: { id: reply.id }
          end

          it 'renders the updated thread back' do
            expect(response.body).to have_text('This is a root comment')
          end

          it 'renders This comment has been deleted' do
            expect(response.body).to have_text('This comment has been deleted')
          end

          it 'renders the replies below' do
            expect(response.body).to have_text('This is a leaf comment')
          end
        end

        context 'with a deleted parent that is the root comment' do
          let!(:leaf) { create(:comment_request, commentable: root_comment.commentable, body: 'This is a leaf comment', parent_id: root_comment.id) }

          before do
            root_comment.blank_or_destroy

            login admin
            delete :destroy, params: { id: leaf.id }
          end

          it 'removes the leaf' do
            expect(response.body).to have_no_text('This is a leaf comment')
          end

          it 'removes the root comment' do
            expect(response.body).to have_no_text('This is a root comment')
            expect(response.body).to have_no_text('This comment has been deleted')
          end
        end

        context 'with all parents deleted' do
          let!(:reply) { create(:comment_request, commentable: root_comment.commentable, body: 'This is a reply comment', parent_id: root_comment.id) }
          let!(:leaf) { create(:comment_request, commentable: root_comment.commentable, body: 'This is a leaf comment', parent_id: reply.id) }

          before do
            root_comment.blank_or_destroy
            reply.blank_or_destroy

            login admin
            delete :destroy, params: { id: leaf.id }
          end

          it 'removes the root comment' do
            expect(response.body).to have_no_text('This is a root comment')
          end

          it 'removes the reply comment' do
            expect(response.body).to have_no_text('This is a reply comment')
          end

          it 'removes the leaf comment' do
            expect(response.body).to have_no_text('This is a leaf comment')
          end

          it 'does not render the deleted comments' do
            expect(response.body).to have_no_text('This comment has been deleted')
          end
        end
      end
    end
  end

  describe 'POST #preview' do
    let(:comment_params) { { comment: { body: '#test comment header' } } }

    before do
      post :preview, params: comment_params, format: :json
    end

    it 'sends success HTTP status when markdown rendered successfully' do
      expect(response).to have_http_status(:success)
    end

    it 'renders comment with Markdown properly' do
      json = response.parsed_body
      expect(json['markdown']).to eq("<h1>test comment header</h1>\n")
    end
  end

  describe 'EDIT update' do
    let(:project) { create(:project) }
    let(:package) { create(:package, project: project) }
    let(:bs_request) { create(:set_bugowner_request) }
    let(:admin_user) { create(:admin_user, login: 'Admin') }
    let(:comment) { create(:comment_project, user: user) }
    let(:other_comment) { create(:comment_project) }

    context 'with invalid commentable_type' do
      let(:comment_params) do
        { comment: { body: 'This is AWESOME!' }, commentable_type: 'FOOBAR', commentable_id: 31_337 }
      end

      it 'fails to create a comment' do
        post :create, params: comment_params
        expect(flash[:error]).to eq('Invalid commentable FOOBAR supplied.')
      end
    end

    context 'with a valid comment' do
      RSpec.shared_examples 'updating a comment' do
        before do
          params = { id: comment.id, comment: { body: "This #{commentable.model_name.singular} is AWFUL!" } }
          put :update, params: params
        end

        it { expect(flash[:success]).to eq('Comment updated successfully.') }
        it { expect(comment.reload.body).to eq("This #{commentable.model_name.singular} is AWFUL!") }
      end

      context 'only Http requests' do
        let(:commentable) { project }

        let(:params) do
          { id: comment.id, comment: { body: "This #{commentable.model_name.singular} is AWFUL!" } }
        end

        it 'responds to html requests' do
          put :update, params: params, format: :html
          expect(response.header['Content-Type']).to include 'text/html'
        end

        it 'does not respond to other json requests' do
          expect { put :update, params: params, format: :json }.to raise_error(ActionController::UnknownFormat)
        end

        it 'does not respond to xml requests' do
          expect { put :update, params: params, format: :xml }.to raise_error(ActionController::UnknownFormat)
        end
      end

      context 'of a project' do
        let(:commentable) { project }

        it_behaves_like 'updating a comment'
      end

      context 'of a package' do
        let(:commentable) { package }

        it_behaves_like 'updating a comment'
      end

      context 'of a bs_request' do
        let(:commentable) { bs_request }

        it_behaves_like 'updating a comment'
      end
    end

    context 'updating a comment without body' do
      let(:commentable) { package }

      before do
        params = { id: comment.id, comment: { body: '' },
                   commentable_type: commentable.class, commentable_id: commentable.id }
        put :update, params: params
      end

      it { expect(flash[:error]).to eq("Failed to update comment: Body can't be blank.") }
    end

    context "does not allow to overwrite the comment's user" do
      it 'raises an error' do
        params = { id: comment.id, comment: { body: 'This project is AWESOME!', user_id: user }, commentable_type: project.class, commentable_id: project.id }
        expect { put :update, params: params }.to raise_error(ActionController::UnpermittedParameters)
      end
    end
  end
end
