require 'rails_helper'

RSpec.describe CommentSnippetPolicy do
  let(:anonymous_user) { create(:user_nobody) }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:other_user) { create(:confirmed_user, login: 'other_user') }
  let(:comment_snippet) { create(:comment_snippet, user: user) }

  subject { CommentSnippetPolicy }

  # rubocop:disable RSpec/RepeatedExample
  # This cop is currently not recognizing the permissions block as separate test
  permissions :destroy? do
    it 'Not logged users cannot destroy comment snippets' do
      expect(subject).not_to permit(nil, comment_snippet)
    end

    it 'Users can destroy their own comment snippets' do
      expect(subject).to permit(user, comment_snippet)
    end

    it 'User cannot destroy comment snippets of other user' do
      expect(subject).not_to permit(other_user, comment_snippet)
    end
    # rubocop:enable RSpec/RepeatedExample
  end

  # rubocop:disable RSpec/RepeatedExample
  # This cop is currently not recognizing the permissions block as separate test
  permissions :update? do
    it 'an anonymous user cannot update comment snippetss' do
      expect(subject).not_to permit(nil, comment_snippet)
    end

    it 'a user can update his own comment snippets' do
      expect(subject).to permit(user, comment_snippet)
    end

    it 'a user cannot update comment snippetss of other users' do
      expect(subject).not_to permit(other_user, comment_snippet)
    end
  end
  # rubocop:enable RSpec/RepeatedExample
end
