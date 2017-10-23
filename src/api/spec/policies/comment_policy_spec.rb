require "rails_helper"

RSpec.describe CommentPolicy do
  let(:anonymous_user) { create(:user_nobody) }
  let(:comment_author) { create(:confirmed_user, login: 'burdenski') }
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { create(:project, name: 'CommentableProject') }
  let(:comment) { create(:comment_project, commentable: project, user: comment_author) }
  let(:comment_deleted_user) { create(:comment_project, commentable: project, user: anonymous_user) }

  subject { CommentPolicy }

  permissions :destroy? do
    it 'Not logged users cannot destroy comments' do
      expect(subject).not_to permit(nil, comment)
    end

    it 'Admin can destroy any comments' do
      expect(subject).to permit(admin_user, comment)
    end

    it 'Users can destroy their own comments' do
      expect(subject).to permit(comment_author, comment)
    end

    it 'Logged users can destroy comments by deleted users' do
      expect(subject).to permit(comment_author, comment_deleted_user)
    end

    it 'User cannot destroy comments of other user' do
      expect(subject).not_to permit(user, comment)
    end
  end
end
