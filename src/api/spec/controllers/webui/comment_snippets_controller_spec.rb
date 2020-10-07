require 'rails_helper'

RSpec.describe Webui::CommentSnippetsController, type: :controller do
  let(:user) { create(:confirmed_user, login: 'luck') }

  before do
    login user
  end

  describe 'POST #create' do
    context 'saving a comment snippet' do
      before do
        params = {
          comment_snippet: {
            title: 'Appreciation reply',
            body: 'Thank you for your contribution.'
          }
        }
        post :create, params: params
      end

      it { expect(flash[:success]).to eq('Reply created successfully.') }
      it { expect(user.comment_snippets.first.title).to eq('Appreciation reply') }
      it { expect(user.comment_snippets.first.body).to eq('Thank you for your contribution.') }
    end

    context 'saving a comment snippet without title' do
      before do
        params = {
          comment_snippet: {
            title: '',
            body: 'Thank you for your contribution.'
          }
        }
        post :create, params: params
      end

      it { expect(flash[:error]).to eq("Failed to create reply: Title can't be blank.") }
      it { expect(user.comment_snippets.count).to eq(0) }
    end

    context 'saving a comment snippet without body' do
      before do
        params = {
          comment_snippet: {
            title: 'Appreciation reply',
            body: ''
          }
        }
        post :create, params: params
      end

      it { expect(flash[:error]).to eq("Failed to create reply: Body can't be blank.") }
      it { expect(user.comment_snippets.count).to eq(0) }
    end
  end

  describe 'DELETE #destroy' do
    let(:comment_snippet) { create(:comment_snippet, user: user) }
    let(:other_comment_snippet) { create(:comment_snippet) }

    context 'can destroy own comments' do
      before do
        delete :destroy, params: { id: comment_snippet.id }
      end

      it { expect(flash[:success]).to eq('Reply deleted successfully.') }
      it { expect(CommentSnippet.where(id: comment_snippet.id)).to eq([]) }
    end

    context 'cannot destroy comment snippet of somebody else' do
      before do
        delete :destroy, params: { id: other_comment_snippet.id }
      end

      it { expect(flash[:success]).to eq(nil) }
      it { expect(CommentSnippet.where(id: other_comment_snippet.id)).to eq([other_comment_snippet]) }
    end
  end

  describe 'EDIT update' do
    let(:comment_snippet) { create(:comment_snippet, user: user) }
    let(:other_comment_snippet) { create(:comment_snippet) }

    context 'with a valid comment snippet' do
      let(:params) do
        {
          id: comment_snippet.id,
          comment_snippet: { title: 'Reply of disgust', body: '... and stay out!' }
        }
      end

      before do
        put :update, params: params
      end

      it { expect(flash[:success]).to eq('Reply updated successfully.') }
      it { expect(comment_snippet.reload.title).to eq('Reply of disgust') }
      it { expect(comment_snippet.reload.body).to eq('... and stay out!') }

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

    context 'updating a comment snippet without title' do
      before do
        params = {
          id: comment_snippet.id,
          comment_snippet: {
            title: '',
            body: '... and stay out!'
          }
        }
        put :update, params: params
      end

      it { expect(flash[:error]).to eq("Failed to update reply: Title can't be blank.") }
    end

    context 'updating a comment snippet without body' do
      before do
        params = {
          id: comment_snippet.id,
          comment_snippet: {
            title: 'Reply of disgust',
            body: ''
          }
        }
        put :update, params: params
      end

      it { expect(flash[:error]).to eq("Failed to update reply: Body can't be blank.") }
    end
  end
end
