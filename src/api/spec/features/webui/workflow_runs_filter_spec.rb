require 'browser_helper'

RSpec.describe 'Workflow runs filters' do
  describe 'listing workflow runs' do
    let!(:pull_request_1_workflow_run) { create(:workflow_run, :succeeded) }
    let(:token) { pull_request_1_workflow_run.token }
    let!(:pull_request_2_workflow_run) { create(:workflow_run, :succeeded, event_source_name: '2', token: token) }
    let!(:closed_pull_request_workflow_run) { create(:workflow_run, :pull_request_closed, token: token) }
    let!(:running_push_workflow_run) { create(:workflow_run, :running, :push, token: token) }
    let!(:succeeded_tag_push_workflow_run) { create(:workflow_run_gitlab, :failed, :tag_push, token: token) }

    before do
      login pull_request_1_workflow_run.token.executor
      visit token_workflow_runs_path(pull_request_1_workflow_run.token)
    end

    describe 'when having no filters selected' do
      it 'shows all the workflow runs' do
        expect(page).to have_text('Displaying all 5 workflow run')
        expect(page).to have_text(pull_request_1_workflow_run.repository_full_name)
        expect(page).to have_text(pull_request_2_workflow_run.repository_full_name)
        expect(page).to have_text(running_push_workflow_run.repository_full_name)
        expect(page).to have_text(closed_pull_request_workflow_run.repository_full_name)
        expect(page).to have_text(succeeded_tag_push_workflow_run.repository_full_name)
      end
    end

    describe 'when having multiple filters selected' do
      before do
        find_by_id('workflow-runs-dropdown-trigger').click if mobile?
        check 'Succeeded'
        check 'Running'
        check 'Pull/Merge Request'
        check 'Push', id: 'push'
        select 'opened', from: 'Action'
        fill_in 'PR/MR', with: '1'
        # TODO: make this work as OR
        # fill_in 'Commit', with: running_push_workflow_run.event_source_name
        click_on 'Apply'
      end

      it 'shows all the matching workflow runs' do
        expect(page).to have_text('Displaying 1 workflow run')
        expect(page).to have_text(pull_request_1_workflow_run.repository_full_name)

        # This gets filtered out by the PR/MR filter set to '1'
        expect(page).to have_no_text(pull_request_2_workflow_run.repository_full_name)
        expect(page).to have_no_text(running_push_workflow_run.repository_full_name)
        # This gets filtered out by the Event type filter set to 'Pull/Merge Request' and 'Push'
        expect(page).to have_no_text(succeeded_tag_push_workflow_run.repository_full_name)
        # This gets filtered out by the Action filter set to 'opened'
        expect(page).to have_no_text(closed_pull_request_workflow_run.repository_full_name)
      end
    end
  end
end
