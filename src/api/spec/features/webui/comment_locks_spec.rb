require 'browser_helper'

RSpec.describe 'CommentLocks', :vcr do
  let!(:moderator_user) { create(:moderator, login: 'moderator') }

  before do
    Flipper.enable(:content_moderation)
  end

  context 'on a request' do
    let(:submitter) { create(:confirmed_user, :with_home, login: 'kugelblitz') }
    let(:receiver) { create(:confirmed_user, :with_home, login: 'titan') }
    let(:target_project) { receiver.home_project }
    let(:target_package) { create(:package, name: 'goal', project_id: target_project.id) }
    let(:source_project) { submitter.home_project }
    let(:source_package) { create(:package, name: 'ball', project_id: source_project.id) }
    let(:bs_request) { create(:delete_bs_request, target_project: target_project, description: 'a long text - ' * 200, creator: submitter) }
    let(:user) { create(:confirmed_user, :with_home, login: 'burdenski') }

    describe 'with comments unlocked' do
      context 'a moderator user' do
        before do
          login moderator_user
          visit request_show_path(bs_request)
        end

        it 'checks comments are unlocked' do
          click_link_or_button('Actions') if mobile?
          expect(page).to have_link('Lock Comments')
          expect(page).to have_no_text('Commenting on this is locked.')
        end

        it 'locks comments' do
          click_link_or_button('Actions') if mobile?
          find_link('Lock Comments').click
          find_button('Lock').click
          expect(page).to have_text('Commenting on this is locked.')
        end
      end

      context 'a non-moderator user' do
        before do
          login user
          visit request_show_path(bs_request)
        end

        it 'cannot lock comments' do
          if mobile?
            expect(page).to have_no_link('Actions')
          else
            expect(page).to have_no_link('Lock Comments')
          end
        end

        it 'can comment' do
          expect(page).to have_no_text('Commenting on this is locked.')
          fill_in 'new_comment_body', with: 'Comment Body'
          find_button('Add comment')
        end
      end
    end

    describe 'with comments locked' do
      let!(:comment_lock) { create(:comment_lock, commentable: bs_request, moderator: moderator_user) }

      context 'a moderator user' do
        before do
          login moderator_user
          visit request_show_path(bs_request)
        end

        it 'checks comments are locked' do
          expect(bs_request.comment_lock).not_to be_nil
          click_link_or_button('Actions') if mobile?
          expect(page).to have_link('Unlock Comments')
          expect(page).to have_text('Commenting on this is locked.')
        end

        it 'unlocks comments' do
          click_link_or_button('Actions') if mobile?
          find_link('Unlock Comments').click
          find_button('Unlock').click
          expect(page).to have_no_text('Commenting on this is locked.')
        end
      end

      context 'a non-moderator user' do
        before do
          login user
          visit request_show_path(bs_request)
        end

        it 'cannot unlock comments' do # rubocop:disable RSpec/ExampleLength
          if mobile?
            expect(page).to have_no_link('Actions')
          else
            expect(page).to have_no_link('Unlock Comments')
          end
          expect(page).to have_no_text('You can remove the lock by clicking on the button below.')
        end

        it 'cannot comment' do
          expect(page).to have_text('Commenting on this is locked.')
          expect(page).to have_no_button('Add comment')
        end
      end

      context 'lock alert for package' do
        let!(:comment_lock_project) { create(:comment_lock, commentable: user.home_project, moderator: moderator_user) }
        let(:package) { create(:package, project: user.home_project, name: 'test_package') }

        before do
          login moderator_user
          visit package_show_path(package.project, package)
        end

        it 'shows comment lock alert' do
          alert = "You can remove the lock by visiting #{package.project.name}"
          expect(page).to have_text(alert)
        end
      end
    end
  end

  context 'on a project' do
    let(:maintainer) { create(:confirmed_user, :with_home, login: 'titan') }
    let(:project) { maintainer.home_project }

    describe 'with comments unlocked' do
      context 'a moderator user' do
        before do
          login moderator_user
          visit project_show_path(project)
        end

        it 'checks comments are unlocked' do
          click_link_or_button('Actions') if mobile?
          expect(page).to have_link('Lock Comments')
          expect(page).to have_no_text('Commenting on this is locked.')
        end

        it 'locks comments' do
          click_link_or_button('Actions') if mobile?
          find_link('Lock Comments').click
          find_button('Lock').click
          expect(page).to have_text('Commenting on this is locked.')
        end
      end
    end

    describe 'with comments locked' do
      let!(:comment_lock) { create(:comment_lock, commentable: project, moderator: moderator_user) }

      context 'a moderator user' do
        before do
          login moderator_user
          visit project_show_path(project)
        end

        it 'checks comments are locked' do
          expect(project.comment_lock).not_to be_nil
          click_link_or_button('Actions') if mobile?
          expect(page).to have_link('Unlock Comments')
          expect(page).to have_text('Commenting on this is locked.')
        end

        it 'unlocks comments' do
          click_link_or_button('Actions') if mobile?
          find_link('Unlock Comments').click
          find_button('Unlock').click
          expect(page).to have_no_text('Commenting on this is locked.')
        end
      end
    end
  end

  context 'on a package' do
    let(:maintainer) { create(:confirmed_user, :with_home, login: 'titan') }
    let(:project) { maintainer.home_project }
    let(:package) { create(:package, name: 'goal', project_id: project.id) }

    describe 'with comments unlocked' do
      context 'a moderator user' do
        before do
          login moderator_user
          visit package_show_path(project, package)
        end

        it 'checks comments are unlocked' do
          click_link_or_button('Actions') if mobile?
          expect(page).to have_link('Lock Comments')
          expect(page).to have_no_text('Commenting on this is locked.')
        end

        it 'locks comments' do
          click_link_or_button('Actions') if mobile?
          find_link('Lock Comments').click
          find_button('Lock').click
          expect(page).to have_text('Commenting on this is locked.')
        end
      end
    end

    describe 'with comments locked' do
      let!(:comment_lock) { create(:comment_lock, commentable: package, moderator: moderator_user) }

      context 'a moderator user' do
        before do
          login moderator_user
          visit package_show_path(project, package)
        end

        it 'checks comments are locked' do
          expect(package.comment_lock).not_to be_nil
          click_link_or_button('Actions') if mobile?
          expect(page).to have_link('Unlock Comments')
          expect(page).to have_text('Commenting on this is locked.')
        end

        it 'unlocks comments' do
          click_link_or_button('Actions') if mobile?
          find_link('Unlock Comments').click
          find_button('Unlock').click
          expect(page).to have_no_text('Commenting on this is locked.')
        end
      end
    end
  end
end
