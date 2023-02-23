require 'rails_helper'

RSpec.describe Webui::RequestController, '#show', vcr: true do
  let(:submitter) { create(:confirmed_user, :with_home, login: 'kugelblitz') }
  let(:receiver) { create(:confirmed_user, :with_home, login: 'titan') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package_with_file, name: 'goal', project_id: target_project.id) }
  let(:source_project) { submitter.home_project }
  let(:source_package) { create(:package, :as_submission_source, name: 'ball', project: source_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           description: 'Please take this',
           creator: submitter,
           target_package: target_package,
           source_package: source_package)
  end

  describe 'GET #show' do
    context 'when the user is part of the beta program' do
      render_views

      before do
        Flipper.enable(:request_show_redesign, receiver)
      end

      context 'when the user has only one submit action' do
        before do
          login receiver
          get :show, params: { number: bs_request.number }
        end

        it 'shows the new redesign page' do
          expect(response.body).to have_text("Request #{bs_request.number}")
          expect(response.body).to have_text('beta program')
        end

        it 'shows no action dropdown'
      end

      # when being able to add reviews
      context 'when the user is the author' do
        before { Flipper.enable(:request_show_redesign, submitter) }

        context 'and having a review in new state' do
          let!(:comment) { create(:comment, commentable: bs_request) }

          before do
            login submitter

            get :show, params: { number: bs_request.number }
          end

          it 'shows the Add Reviewer button' do
            expect(response.body).to have_selector('button[title="Add Reviewer"]')
          end

          it 'shows the request comment' do
            expect(response.body).to have_selector('.timeline-item', text: comment.body)
          end

          it { expect(response.body).to have_text('No issues are mentioned for this request action.') }
        end

        context 'and having a review in declined state' do
          let(:project) { create(:project) }
          let!(:comment) { create(:comment, commentable: bs_request) }

          before do
            bs_request.update(state: :declined)
            login submitter

            get :show, params: { number: bs_request.number }
          end

          it 'shows the reopen button' do
            expect(response.body).to have_selector('input[type="submit"][value="Reopen request"]')
          end

          it 'shows the request comment' do
            expect(response.body).to have_selector('.timeline-item', text: comment.body)
          end

          it { expect(response.body).to have_text('No issues are mentioned for this request action.') }
        end
      end

      context 'and having a review in new state' do
        let!(:comment) { create(:comment, commentable: bs_request) }

        before do
          login receiver

          get :show, params: { number: bs_request.number }
        end

        # Use case with open reviews
        context 'when the user is not the author' do
          let(:project) { create(:project) }
          let(:bs_request) do
            create(:bs_request_with_submit_action,
                   review_by_project: project,
                   target_package: target_package,
                   source_package: source_package)
          end

          it { expect(response.body).to have_text('1 Pending Review') }

          it 'shows the request comment' do
            expect(response.body).to have_selector('.timeline-item', text: comment.body)
          end

          it { expect(response.body).to have_text('No issues are mentioned for this request action.') }
        end
      end

      context 'when having build results' do
        context 'for requests against non staging projects' do
          let(:data_project) { bs_request.bs_request_actions.first.source_project }
          let(:data_package) { bs_request.bs_request_actions.first.source_package }

          before do
            login receiver
            get :show, params: { number: bs_request.number }
          end

          it {
            expect(response.body).to have_selector("div.build-results-content[data-project='#{data_project}'][data-package='#{data_package}']")
          }

          it { expect(response.body).to have_text('No issues are mentioned for this request action.') }
        end

        context 'for requests against staging projects' do
          let(:staging_workflow) { create(:staging_workflow_with_staging_projects) }
          let(:group) { staging_workflow.managers_group }
          let(:staging_project) { staging_workflow.staging_projects.first }
          let(:bs_request) do
            create(:bs_request_with_submit_action,
                   staging_project: staging_project,
                   review_by_project: staging_project,
                   target_package: target_package,
                   source_package: source_package)
          end
          let(:review) { bs_request.reviews.first }
          let!(:comment) { create(:comment, commentable: bs_request) }

          before do
            group.users << receiver
            login receiver
            get :show, params: { number: bs_request.number }
          end

          it { expect(response.body).to have_text('From staging project') }
          it { expect(response.body).to have_selector('.build-results-content > .font-italic > a', text: staging_project.name) }
          it { expect(response.body).to have_text('No issues are mentioned for this request action.') }
        end
      end

      context 'when refreshing the changes' do
        let(:bs_request) do
          create(:bs_request_with_submit_action,
                 target_package: target_package,
                 source_package: source_package)
        end

        before do
          login receiver
          # rubocop:disable RSpec/AnyInstance
          allow_any_instance_of(BsRequest).to receive(:webui_actions).and_return([{
                                                                                   type: :submit,
                                                                                   id: bs_request.bs_request_actions.first.id,
                                                                                   number: bs_request.number,
                                                                                   sprj: source_project.name,
                                                                                   spkg: source_package.name,
                                                                                   tprj: target_project.name,
                                                                                   tpkg: target_package.name,
                                                                                   sourcediff: [{ error: 'diff not yet in cache' }],
                                                                                   diff_not_cached: true
                                                                                 }])
          # rubocop:enable RSpec/AnyInstance

          get :show, params: { number: bs_request.number, diffs: true }
        end

        it { expect(response.body).to have_text('Crunching the latest data. Refresh again in a few seconds') }

        it { expect(response.body).to have_text('No issues are mentioned for this request action.') }
      end
    end
  end
end
