require 'browser_helper'

RSpec.describe 'User beta features', type: :feature, js: true do
  let(:beta_feature) { 'something_cool' }

  before do
    stub_const('ENABLED_FEATURE_TOGGLES', [{ name: beta_feature, description: 'A new cool design!' },
                                           { name: 'new_feature_123', description: 'New feature for you' }])
    Flipper[beta_feature].enable
  end

  describe 'when the user is not in the beta program' do
    let(:user) { create(:confirmed_user, login: 'jane_doe') }

    before do
      login user
      visit my_beta_features_path
    end

    context 'when joining the beta program' do
      before do
        check('user[in_beta]')
      end

      it 'displays a list of the beta features' do
        expect(page).to have_text('Something cool')
        expect(page).to have_text('A new cool design!')
        expect(page).to have_text('New feature 123')
        expect(page).to have_text('New feature for you')
      end

      it 'updates the user' do
        expect(page).to have_checked_field('user[in_beta]', visible: :hidden) # visible for custom Bootstrap checkbox
        expect(page).to have_text("User data for user 'jane_doe' successfully updated.")
        expect(user.reload.in_beta).to be_truthy
      end
    end
  end

  describe 'when the user is in the beta program' do
    let(:user) { create(:confirmed_user, :in_beta, login: 'john_doe') }

    before do
      login user
    end

    context 'when leaving the beta program' do
      before do
        visit my_beta_features_path
        uncheck('user[in_beta]')
      end

      it 'does not display a list of the beta features' do
        expect(page).not_to have_text('Something cool')
        expect(page).not_to have_text('A new cool design!')
        expect(page).not_to have_text('New feature 123')
        expect(page).not_to have_text('New feature for you')
      end

      it 'updates the user as part of the beta program' do
        expect(page).to have_unchecked_field('user[in_beta]', visible: :hidden) # visible for custom Bootstrap checkbox
        expect(page).to have_text("User data for user 'john_doe' successfully updated.")
        expect(user.reload.in_beta).to be_falsey
      end
    end

    context 'when enabling a beta feature which is not already enabled' do
      before do
        create(:disabled_beta_feature, name: beta_feature, user: user)
        visit my_beta_features_path
        check('feature[something_cool]')
      end

      it 'enables the beta feature' do
        within('#flash') do
          expect(page).to have_text("You enabled the beta feature 'Something cool'.")
        end
        expect(page).to have_checked_field('feature[something_cool]', visible: :hidden) # visible for custom Bootstrap checkbox
      end
    end

    context 'when enabling a beta feature which is already enabled' do
      let!(:disabled_beta_feature) { create(:disabled_beta_feature, name: beta_feature, user: user) }

      before do
        visit my_beta_features_path
        disabled_beta_feature.destroy
        check('feature[something_cool]')
      end

      it 'does nothing' do
        within('#flash') do
          expect(page).to have_text("You already enabled the beta feature 'Something cool'.")
        end
      end
    end

    context 'when disabling a beta feature which is not already disabled' do
      before do
        visit my_beta_features_path
        uncheck('feature[something_cool]')
      end

      it 'disables the beta feature' do
        within('#flash') do
          expect(page).to have_text("You disabled the beta feature 'Something cool'.")
        end
        expect(page).to have_unchecked_field('feature[something_cool]', visible: :hidden) # visible for custom Bootstrap checkbox
      end
    end

    context 'when disabling a beta feature which is already disabled' do
      before do
        visit my_beta_features_path
        create(:disabled_beta_feature, name: beta_feature, user: user)
        uncheck('feature[something_cool]')
      end

      it 'does nothing' do
        within('#flash') do
          expect(page).to have_text("You already disabled the beta feature 'Something cool'.")
        end
      end
    end
  end
end
