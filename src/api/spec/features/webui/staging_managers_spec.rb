require 'browser_helper'
require 'webmock/rspec'

RSpec.feature 'Staging Managers', type: :feature, js: true do
  let!(:user) { create(:confirmed_user, login: 'stagingmanager') }

  describe 'for an anonymous user' do
    let!(:staging_workflow) { create(:staging_workflow, project: user.home_project) }

    before do
      visit staging_workflow_staging_workflows_managers_path(staging_workflow_id: staging_workflow.id)
    end

    scenario 'it is not possible to add a staging manager to a staging workflow' do
      expect(page).not_to have_text('Add staging manager')
    end

    scenario 'it is not possible to remove a staging manager from a staging workflow' do
      expect(page).not_to have_link(class: 'remove-staging-manager')
    end
  end

  describe 'for a logged-in user in a staging workflow for a project' do
    before do
      login user
    end

    describe 'he/she can manage' do
      let!(:staging_workflow) { create(:staging_workflow, project: user.home_project) }

      describe 'add a staging manager to a staging workflow' do
        before do
          visit staging_workflow_staging_workflows_managers_path(staging_workflow_id: staging_workflow.id)

          click_link('Add staging manager')
        end

        scenario 'it fails when he/she already is' do
          staging_workflow.managers << user

          within('#add-staging-manager-modal') do
            fill_in 'staging_manager', with: user.login

            click_button('Accept')
          end

          expect(page).to have_text("#{user.login} is already a staging manager for #{staging_workflow.project}")
          expect(page).to have_current_path(staging_workflow_staging_workflows_managers_path(staging_workflow_id: staging_workflow.id))
        end

        scenario 'it succeeds when he/she is not already' do
          within('#add-staging-manager-modal') do
            fill_in 'staging_manager', with: user.login

            click_button('Accept')
          end

          expect(page).to have_text("Staging manager #{user.login} for #{staging_workflow.project} was successfully added")
          expect(page).to have_current_path(staging_workflow_staging_workflows_managers_path(staging_workflow_id: staging_workflow.id))
        end
      end

      describe 'remove a staging manager from a staging workflow' do
        before do
          staging_workflow.managers << user

          visit staging_workflow_staging_workflows_managers_path(staging_workflow_id: staging_workflow.id)

          click_on(class: 'remove-staging-manager')

          within("#remove-staging-manager-#{user.id}") do
            click_button('Remove')
          end
        end

        scenario 'it succeeds' do
          expect(page).to have_text("Staging manager #{user.login} for #{staging_workflow.project} was successfully removed")
        end
      end
    end

    describe 'for a project he/she cannot manage' do
      let!(:staging_workflow) { create(:staging_workflow) }

      before do
        visit staging_workflow_staging_workflows_managers_path(staging_workflow_id: staging_workflow.id)
      end

      scenario 'it is not possible to add a staging manager to a staging workflow' do
        expect(page).not_to have_text('Add staging manager')
      end

      scenario 'it is not possible to remove a staging manager from a staging workflow' do
        expect(page).not_to have_link(class: 'remove-staging-manager')
      end
    end
  end
end
