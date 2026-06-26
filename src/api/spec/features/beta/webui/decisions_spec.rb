require 'browser_helper'

RSpec.describe 'Decisions', :js, :vcr do
  before do
    Flipper.enable(:content_moderation)
  end

  let(:reporter) { create(:confirmed_user, login: 'foo') }
  let(:moderator) { create(:moderator, login: 'baz') }

  def fill_decisions_modal(reportable)
    within("#reports-modal-#{reportable.class.to_s.downcase}-#{reportable.id}") do
      fill_in id: 'decision_reason', with: 'Reason for reporting is correct.'
      select('favor', from: 'decision[type]')
      click_button('Submit')
    end
  end

  describe 'project' do
    let(:project) { create(:project, name: 'against_the_rules') }
    let!(:report_for_project) { create(:report, reportable: project, reason: 'This project does not follow the rules!', reporter: reporter) }

    before do
      login(moderator)
      visit project_show_path(project)
    end

    it 'creates the decision for a moderator' do
      expect(page).to have_text('This project has 1 report .')
      click_link('1 report')
      fill_decisions_modal(project)

      expect(page).to have_text('Decision created successfully')
      expect(Decision.count).to eq(1)
    end
  end

  describe 'package' do
    let(:project) { create(:project, name: 'factory') }
    let(:package) { create(:package_with_maintainer, project: project, name: 'against_the_rules') }
    let!(:report_for_package) { create(:report, reportable: package, reason: 'This package does not follow the rules!', reporter: reporter) }

    before do
      login(moderator)
      visit package_show_path(project, package)
    end

    it 'creates the decision for a moderator' do
      expect(page).to have_text('This package has 1 report .')
      click_link('1 report')
      fill_decisions_modal(package)

      expect(page).to have_text('Decision created successfully')
      expect(Decision.count).to eq(1)
    end
  end

  describe 'user' do
    let(:spammer) { create(:confirmed_user, login: 'spammer') }
    let!(:report_for_user) { create(:report, reportable: spammer, reason: 'User produces spam comments!', reporter: reporter) }

    before do
      login(moderator)
      visit user_path(spammer)
    end

    it 'creates the decision for a moderator' do
      expect(page).to have_text('This user has 1 report .')
      within('.basic-info') { click_link('1 report') }
      fill_decisions_modal(spammer)

      expect(page).to have_text('Decision created successfully')
      expect(Decision.count).to eq(1)
    end
  end

  describe 'comment on request' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }
    let(:spammer) { create(:confirmed_user, login: 'trouble_maker') }
    let(:project) { create(:project, name: 'some_random_project') }
    let(:bs_request) { create(:delete_bs_request, target_project: project, description: 'Delete this project!', creator: user) }
    let(:comment_on_request) { create(:comment, commentable: bs_request, user: spammer) }
    let!(:report_for_comment) { create(:report, reportable: comment_on_request, reason: 'This is spam!', reporter: reporter) }

    before do
      login moderator
      visit request_show_path(bs_request)
    end

    it 'creates the decision for a moderator' do
      expect(page).to have_text('This comment has 1 report .')
      within("#comment-#{comment_on_request.id}-body") { click_link('1 report') }
      fill_decisions_modal(comment_on_request)

      expect(page).to have_text('Decision created successfully')
      expect(Decision.count).to eq(1)
    end
  end

  describe 'comment on project' do
    let(:spammer) { create(:confirmed_user, login: 'trouble_maker') }
    let(:project) { create(:project, name: 'factory') }
    let(:comment_on_project) { create(:comment_project, commentable: project, user: spammer) }
    let!(:report_for_comment) { create(:report, reportable: comment_on_project, reason: 'This is spam!', reporter: reporter) }

    before do
      login(moderator)
      visit project_show_path(project)
    end

    it 'creates the decision for a moderator' do
      expect(page).to have_text('This comment has 1 report .')
      within('#comments-list') { click_link('1 report') }
      fill_decisions_modal(comment_on_project)

      expect(page).to have_text('Decision created successfully')
      expect(Decision.count).to eq(1)
    end
  end

  describe 'comment on package' do
    let(:spammer) { create(:confirmed_user, login: 'trouble_maker') }
    let(:project) { create(:project, name: 'factory') }
    let(:package) { create(:package, name: 'hello', project: project) }
    let(:comment_on_package) { create(:comment_package, commentable: package, user: spammer) }
    let!(:report_for_comment) { create(:report, reportable: comment_on_package, reason: 'This is spam!', reporter: reporter) }

    before do
      login(moderator)
      visit package_show_path(project, package)
    end

    it 'creates the decision for a moderator' do
      expect(page).to have_text('This comment has 1 report .')
      within('#comments-list') { click_link('1 report') }
      fill_decisions_modal(comment_on_package)

      expect(page).to have_text('Decision created successfully')
      expect(Decision.count).to eq(1)
    end
  end
end
