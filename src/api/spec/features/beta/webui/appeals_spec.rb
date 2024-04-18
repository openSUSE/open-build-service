require 'browser_helper'

RSpec.describe 'Appeals', :js, :vcr do
  before do
    Flipper.enable(:content_moderation)
  end

  describe 'appealing a decision' do
    let(:moderator) { create(:confirmed_user) }
    let(:user) { create(:confirmed_user) }
    let(:comment) { create(:comment_package, user: user) }
    let(:report) { create(:report, reportable: comment) }
    let!(:decision) { Decision.create!(type: 'DecisionFavored', reason: "It's spam indeed", reports: [report], moderator: moderator) }

    before do
      EventSubscription.create!(eventtype: Event::FavoredDecision.name,
                                channel: :web,
                                receiver_role: :offender,
                                enabled: true)
      EventSubscription.create!(eventtype: Event::AppealCreated.name,
                                channel: :web,
                                receiver_role: :moderator,
                                enabled: true)
      SendEventEmailsJob.perform_now
      login user
      visit my_notifications_path
    end

    it 'displays the message' do
      click_link('Appeal')
      fill_in id: 'appeal_reason', with: 'I think this is not spam'
      click_button('Submit')
      expect(page).to have_text('Appeal created successfully!')
    end
  end
end
