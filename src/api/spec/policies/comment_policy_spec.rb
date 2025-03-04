RSpec.describe CommentPolicy do
  subject { described_class }

  let(:anonymous_user) { create(:user_nobody) }
  let(:comment_author) { create(:confirmed_user, login: 'burdenski') }
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:other_user) { create(:confirmed_user, login: 'other_user') }
  let(:project) { create(:project, name: 'CommentableProject') }
  let(:package) { create(:package, :as_submission_source, name: 'CommentablePackage', project: project) }
  let(:comment) { create(:comment_project, commentable: project, user: comment_author) }
  let(:request) { create(:bs_request_with_submit_action, target_package: package) }
  let(:comment_on_package) { create(:comment_package, commentable: package, user: comment_author) }
  let(:comment_on_request) { create(:comment_request, commentable: request, user: comment_author) }
  let(:comment_deleted) { create(:comment_project, commentable: project, user: anonymous_user) }

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

    it 'Anonymous users cannot destroy already deleted comments' do
      expect(subject).not_to permit(nil, comment_deleted)
    end

    it 'Logged users cannot destroy already deleted comments' do
      expect(subject).not_to permit(comment_author, comment_deleted)
    end

    it 'Admin cannot destroy already deleted comments' do
      expect(subject).not_to permit(admin_user, comment_deleted)
    end

    it 'User cannot destroy comments of other user' do
      expect(subject).not_to permit(user, comment)
    end

    context 'with a comment on a Package' do
      before do
        allow(user).to receive(:local_permission?).with('change_package', package).and_return(true)
        allow(other_user).to receive(:local_permission?).with('change_package', package).and_return(false)
      end

      it { is_expected.to permit(user, comment_on_package) }
      it { is_expected.not_to permit(other_user, comment_on_package) }
    end

    context 'with a comment on a Project' do
      before do
        allow(user).to receive(:local_permission?).with('change_project', project).and_return(true)
        allow(other_user).to receive(:local_permission?).with('change_project', project).and_return(false)
      end

      it { is_expected.to permit(user, comment) }
      it { is_expected.not_to permit(other_user, comment) }
    end

    context 'with a comment on a Request' do
      before do
        allow(request).to receive(:target_maintainer?).with(user).and_return(true)
        allow(request).to receive(:target_maintainer?).with(other_user).and_return(false)
      end

      it { is_expected.to permit(user, comment_on_request) }
      it { is_expected.not_to permit(other_user, comment_on_request) }
    end

    context 'with a comment on a Report' do
      let(:user_with_moderator_role) { create(:moderator) }
      let(:another_user_with_moderator_role) { create(:moderator) }
      let(:comment_on_report) { create(:comment_request, user: user_with_moderator_role) }

      it { is_expected.to permit(user_with_moderator_role, comment_on_report) }
      it { is_expected.not_to permit(another_user_with_moderator_role, comment_on_report) }
      it { is_expected.not_to permit(other_user, comment_on_report) }
    end
  end

  permissions :update? do
    it 'an anonymous user cannot update comments' do
      expect(subject).not_to permit(nil, comment)
    end

    it 'an admin user cannot update other comments' do
      expect(subject).not_to permit(admin_user, comment)
    end

    it 'a user can update their own comments' do
      expect(subject).to permit(comment_author, comment)
    end

    it 'a user cannot update comments of other users' do
      expect(subject).not_to permit(other_user, comment)
    end

    context 'with a deleted comment' do
      it 'a normal user is unable to update a deleted comment' do
        expect(subject).not_to permit(other_user, comment_deleted)
      end

      it 'an admin user is unable to update a deleted comment' do
        expect(subject).not_to permit(admin_user, comment_deleted)
      end

      it 'an anonymous user is unable to update a deleted comment' do
        expect(subject).not_to permit(anonymous_user, comment_deleted)
      end
    end
  end

  permissions :reply? do
    it 'an anonymous user cannot reply to comments' do
      expect(subject).not_to permit(nil, comment)
    end

    it 'an admin user can reply to other comments' do
      expect(subject).to permit(admin_user, comment)
    end

    it 'a user can reply to comments' do
      expect(subject).to permit(comment_author, comment)
    end

    context 'with a deleted comment' do
      it 'a normal user is unable to reply to a deleted comment' do
        expect(subject).not_to permit(other_user, comment_deleted)
      end

      it 'an admin user is unable to reply to a deleted comment' do
        expect(subject).not_to permit(admin_user, comment_deleted)
      end

      it 'an anonymous user is unable to reply to a deleted comment' do
        expect(subject).not_to permit(anonymous_user, comment_deleted)
      end
    end
  end

  permissions :moderate? do
    it 'a not logged-in user cannot moderate comments' do
      expect(subject).not_to permit(nil, comment)
    end

    it 'an anonymous user cannot moderate comments' do
      expect(subject).not_to permit(anonymous_user, comment)
    end

    it 'a non-admin user cannot moderate comments' do
      expect(subject).not_to permit(other_user, comment)
    end

    it 'an admin user can moderate comments' do
      expect(subject).to permit(admin_user, comment)
    end

    context 'with a deleted comment' do
      it 'no one is able to moderate a deleted comment' do
        expect(subject).not_to permit(admin_user, comment_deleted)
      end
    end

    context 'when the moderator is a staff member' do
      let(:staff_user) { create(:staff_user) }

      it 'an staff member can moderate comments' do
        expect(subject).to permit(staff_user, comment)
      end
    end

    context 'when the user has the moderator role assigned' do
      let(:user_with_moderator_role) { create(:moderator) }

      it 'can moderate comments' do
        expect(subject).to permit(user_with_moderator_role, comment)
      end
    end
  end

  permissions :history? do
    let(:staff_user) { create(:staff_user) }
    let(:moderator) { create(:moderator) }
    let(:comment_moderated) { create(:comment_project, commentable: project, moderated_at: DateTime.now.utc, moderator_id: moderator.id) }

    before do
      Flipper.enable(:content_moderation)
    end

    it { is_expected.to permit(other_user, comment) }
    it { is_expected.not_to permit(other_user, comment_deleted) }
    it { is_expected.not_to permit(other_user, comment_moderated) }

    it { is_expected.to permit(moderator, comment_deleted) }
    it { is_expected.to permit(admin_user, comment_deleted) }
    it { is_expected.to permit(staff_user, comment_deleted) }

    it { is_expected.to permit(moderator, comment_moderated) }
    it { is_expected.to permit(admin_user, comment_moderated) }
    it { is_expected.to permit(staff_user, comment_moderated) }
  end

  permissions :create? do
    it { is_expected.not_to permit(anonymous_user, comment) }
    it { is_expected.not_to permit(nil, comment) }
    it { is_expected.to permit(comment_author, comment) }
    it { is_expected.to permit(admin_user, comment) }

    context 'for a user which is censored' do
      before do
        comment_author.censored = true
      end

      it { is_expected.not_to permit(comment_author, comment) }
    end

    context 'for a commentable with a comment lock set' do
      let(:maintainer) { other_user }
      let(:project_with_maintainer) { create(:project, maintainer: maintainer) }
      let!(:comment_lock) { create(:comment_lock, commentable: project_with_maintainer, moderator: maintainer) }
      let(:comment_on_comment_locked_project) { build(:comment_project, commentable: project_with_maintainer, user: author) }

      context 'for the maintainer of the commentable' do
        let(:author) { maintainer }

        it { is_expected.to permit(author, comment_on_comment_locked_project) }
      end

      context 'for a user without maintainer role on the commentable' do
        let(:author) { comment_author }

        it { is_expected.not_to permit(author, comment_on_comment_locked_project) }
      end

      context 'for an admin' do
        let(:author) { admin_user }

        it { is_expected.to permit(author, comment_on_comment_locked_project) }
      end
    end

    context 'for a commentable which is a report' do
      let(:user_with_moderator_role) { create(:moderator) }
      let(:another_user) { create(:confirmed_user) }
      let(:comment_on_report) { build(:comment_request, user: user_with_moderator_role) }

      it { is_expected.to permit(user_with_moderator_role, comment_on_report) }
      it { is_expected.to permit(admin_user, comment_on_report) }
      it { is_expected.to permit(comment_author, comment_on_report) }
      it { is_expected.to permit(another_user, comment_on_report) }
    end
  end
end
