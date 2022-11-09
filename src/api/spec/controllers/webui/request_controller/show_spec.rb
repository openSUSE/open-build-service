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
        let!(:comment) { create(:comment, commentable: bs_request) }

        before do
          login receiver
          get :show, params: { number: bs_request.number }
        end

        it 'shows the new redesign page' do
          expect(response.body).to have_text("Request #{bs_request.number}")
        end

        it 'shows the history elements for the request' do
          expect(response.body).to have_text("Created by\n #{submitter.name}")
          expect(response.body).to have_text("(#{bs_request.creator})\ncreated this request")
        end

        it 'shows the request comment' do
          expect(response.body).to have_selector('.timeline-item', text: comment.body)
        end

        it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
        it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
      end

      # TODO: prepare one use case per action and check the dropdown shows the corresponding action
      context 'when the request has multiple submit actions' do
        let(:target_project2) { receiver.home_project }
        let(:target_package2) { create(:package_with_file, name: 'goal2', project_id: target_project2.id) }
        let!(:comment) { create(:comment, commentable: bs_request) }

        before do
          login receiver

          bs_request.bs_request_actions << create(:bs_request_action_submit,
                                                  source_project: bs_request.bs_request_actions.first.source_project,
                                                  source_package: bs_request.bs_request_actions.first.source_package,
                                                  target_project: target_project2,
                                                  target_package: target_package2)

          get :show, params: { number: bs_request.number }
        end

        it { expect(controller).to render_template('webui/request/_actions_details') }
        it { expect(response.body).to have_text('This request contains multiple actions') }
        it { expect(controller).to render_template('webui/request/_action_text') }
        it { expect(response.body).to have_text("Showing\nSubmit package #{bs_request.bs_request_actions.first.source_project} / #{bs_request.bs_request_actions.first.source_package}") }

        it 'shows the request comment' do
          expect(response.body).to have_selector('.timeline-item', text: comment.body)
        end

        it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
        it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
      end

      context 'when the request has a set bugowner action' do
        let(:set_bugowner_action) { create(:bs_request_action_set_bugowner) }

        before do
          login receiver

          bs_request.bs_request_actions << set_bugowner_action

          get :show, params: { number: bs_request.number }
        end

        xit { expect(controller).to render_template('webui/request/_actions_details') }
        xit { expect(response.body).to have_text('This request contains multiple actions') }
        xit { expect(controller).to render_template('webui/request/_action_text') }
        # TODO: Find why the bug owner action is not triggering the _action_details stuff
        xit { expect(response).to have_link('Set Bugowner') }
      end

      # Use case with accepted reviews
      context 'when having an accepted review' do
        let(:project) { create(:project) }
        let(:bs_request) do
          create(:bs_request_with_submit_action,
                 review_by_project: project,
                 target_package: target_package,
                 source_package: source_package)
        end
        let(:review) { bs_request.reviews.first }
        let!(:comment) { create(:comment, commentable: bs_request) }

        before do
          login receiver

          # TODO: Move this to a factory so we can crank out accepted reviews
          review.change_state(:accepted, 'Because why not?')

          get :show, params: { number: bs_request.number }
        end

        it { expect(controller).to render_template('webui/request/beta_show_tabs/_conversation') }
        it { expect(controller).to render_template('webui/request/beta_show_tabs/_review_summary') }

        it { expect(review.reviewer).not_to be_nil }
        it { expect(response.body).to have_text('Reviews') }
        it { expect(response.body).to have_text("by\n#{review.reviewer}") }

        it 'shows the request comment' do
          expect(response.body).to have_selector('.timeline-item', text: comment.body)
        end

        it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
        it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
      end

      # Use case with declined reviews
      context 'when having a declined review' do
        let(:project) { create(:project) }
        let(:bs_request) do
          create(:bs_request_with_submit_action,
                 review_by_project: project,
                 target_package: target_package,
                 source_package: source_package)
        end
        let(:review) { bs_request.reviews.first }
        let!(:comment) { create(:comment, commentable: bs_request) }

        before do
          login receiver

          # TODO: Move this to a factory so we can crank out declined reviews
          review.change_state(:declined, "Didn't like it")

          get :show, params: { number: bs_request.number }
        end

        it { expect(controller).to render_template('webui/request/beta_show_tabs/_conversation') }
        it { expect(controller).to render_template('webui/request/beta_show_tabs/_review_summary') }

        it { expect(review.reviewer).not_to be_nil }
        it { expect(response.body).to have_text('Reviews') }
        it { expect(response.body).to have_text("by\n#{review.reviewer}") }

        it 'shows the request comment' do
          expect(response.body).to have_selector('.timeline-item', text: comment.body)
        end

        it { expect(controller).to render_template('webui/request/beta_show_tabs/_rpm_lint_result') }
        it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
        it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
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

          it { expect(controller).to render_template('webui/request/beta_show_tabs/_conversation') }

          it 'shows the Add Review button' do
            expect(response.body).to have_selector('a[title="Add a Review"]')
          end

          it 'shows the request comment' do
            expect(response.body).to have_selector('.timeline-item', text: comment.body)
          end

          it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
          it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
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

          it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
          it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
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

          it { expect(controller).to render_template('webui/request/beta_show_tabs/_conversation') }
          it { expect(controller).to render_template('webui/request/beta_show_tabs/_review_summary') }

          it { expect(response.body).to have_text('Reviews') }
          it { expect(response.body).to have_selector('i.fas.fa-2xs.fa-circle.text-warning.align-middle.pr-2') }

          it 'shows the request comment' do
            expect(response.body).to have_selector('.timeline-item', text: comment.body)
          end

          it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
          it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
        end

        context 'when the user is the target maintainer' do
          it 'shows the accept request button' do
            expect(response.body).to have_selector('input[type="submit"][value="Accept request"]')
          end

          it 'shows the request comment' do
            expect(response.body).to have_selector('.timeline-item', text: comment.body)
          end

          context 'and is also the author'

          context 'but it is not the author' do
            it 'does show the decline request button' do
              expect(response.body).to have_selector('input[type="submit"][value="Decline request"]')
            end
          end
        end

        context 'when the user is not the target maintainer' do
          it 'shows the request comment' do
            expect(response.body).to have_selector('.timeline-item', text: comment.body)
          end

          it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
          it { expect(response.body).to have_text("The mentioned issues aren't here yet") }

          it 'does not show the request accept button' do
            expect(response.body).not_to have_text('Accept request')
          end
        end
      end

      # Use case with open staging reviews
      context 'when having a review open for a staging project' do
        context 'when the user is not the author' do
          let(:staging_workflow) { create(:staging_workflow_with_staging_projects) }
          let(:group) { staging_workflow.managers_group }
          let(:project) { staging_workflow.staging_projects.first }
          let(:bs_request) do
            create(:bs_request_with_submit_action,
                   review_by_project: project,
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

          it { expect(controller).to render_template('webui/request/beta_show_tabs/_conversation') }
          it { expect(response.body).to have_text('Is staged in') }
          it { expect(response.body).to have_selector('.timeline-item', text: comment.body) }

          it 'shows the request comment' do
            expect(response.body).to have_text(comment.body)
          end

          it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
          it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
        end
      end

      # Use case with superseeded requests that show included history elements
      context 'when having a superseding request' do
        let(:project) { create(:project) }
        let(:review) { request_with_review_by_project.reviews.first }
        let(:superseded_request) { create(:superseded_bs_request, superseded_by_request: bs_request) }
        let!(:comment) { create(:comment, commentable: superseded_request) }

        before do
          comment
          login receiver

          get :show, params: { number: bs_request.number }
        end

        it { expect(controller).to render_template('webui/request/beta_show_tabs/_conversation') }

        it { expect(bs_request.superseding).not_to be_empty }
        it { expect(response.body).to have_text("Expand history from superseded request ##{bs_request.superseding.first.number}") }
        it { expect(response.body).to have_selector('div.collapse.mb-4#collapse-superseding > .timeline-item', text: comment) }
        it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
        it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
      end

      # TODO: Check build results if any
      context 'when having build results' do
        context 'for requests against non staging projects' do
          let(:data_project) { bs_request.bs_request_actions.first.source_project }
          let(:data_package) { bs_request.bs_request_actions.first.source_package }

          before do
            login receiver
            get :show, params: { number: bs_request.number }
          end

          it { expect(controller).to render_template('webui/request/beta_show_tabs/_build_results') }

          it {
            expect(response.body).to have_selector("div.build-results-content[data-project='#{data_project}'][data-package='#{data_package}']")
          }

          it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
          it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
        end

        # TODO: Check build results for staged request
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

          it { expect(controller).to render_template('webui/request/beta_show_tabs/_build_results') }
          it { expect(response.body).to have_text('From staging project') }
          it { expect(response.body).to have_selector('.build-results-content > .font-italic > a', text: staging_project.name) }
          it { expect(response.body).to have_text("The RPM Lint results aren't here yet") }
          it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
        end
      end

      # TODO: Check source diff component loading
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

        it { expect(response.body).to have_text("The mentioned issues aren't here yet") }
      end
    end
  end
end
