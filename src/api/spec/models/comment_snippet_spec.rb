require 'rails_helper'

RSpec.describe CommentSnippet, type: :model do
  let(:comment_snippet) { create(:comment_snippet) }

  describe 'has a valid Factory' do
    it { expect(comment_snippet).to be_valid }
  end

  describe 'save' do
    it 'stores emoji' do
      comment_snippet.title = 'Thank you for your contribution'
      comment_snippet.body = '😁'
      comment_snippet.save
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user).inverse_of(:comment_snippets) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:user) }
  end
end
