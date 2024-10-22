require 'browser_helper'

RSpec.describe 'Requests_Submissions', :js, :vcr do
  let(:submitter) { create(:confirmed_user, :with_home, login: 'madam_submitter') }
  let(:source_project) { submitter.home_project }
  let(:source_package) { create(:package_with_file, name: 'Quebec', project: source_project) }
  let(:receiver) { create(:confirmed_user, :with_home, login: 'mr_receiver') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package_with_file, name: 'Quebec', project: target_project) }
  let(:bs_request_description) { 'Youpi!' }

  context 'submit package' do
    describe 'setting a target package' do
      it 'creates a BsRequest with target package name' do
        login submitter
        visit package_show_path(source_project, source_package)
        desktop? ? click_link('Submit Package') : click_menu_link('Actions', 'Submit Package')
        fill_in('To target project:', with: target_project.name)
        fill_in('To target package:', with: target_package.name)
        fill_in('bs_request_description', with: bs_request_description)
        click_button('Submit')
        expect(page).to have_text("Submit package #{source_project} / #{source_package} " \
                                  "to package #{target_project} / #{target_package}")
        expect(page).to have_css('#description-text', text: bs_request_description)
        expect(page).to have_text('In state new')
      end
    end

    describe 'not setting a target package' do
      it 'creates a BsRequest with the source package name' do
        login submitter
        visit package_show_path(source_project, source_package)
        desktop? ? click_link('Submit Package') : click_menu_link('Actions', 'Submit Package')
        fill_in('To target project:', with: target_project.name)
        fill_in('bs_request_description', with: bs_request_description)
        click_button('Submit')
        expect(page).to have_text("Submit package #{source_project} / #{source_package} " \
                                  "to package #{target_project} / #{source_package}")
        expect(page).to have_css('#description-text', text: bs_request_description)
        expect(page).to have_text('In state new')
      end
    end

    describe 'supersede a request' do
      let!(:bs_request_to_supersede) do
        create(:bs_request_with_submit_action, source_project: source_project, source_package: source_package,
                                               target_project: target_project, target_package: target_package,
                                               creator: submitter)
      end
      let!(:bs_request_to_supersede2) do
        create(:bs_request_with_submit_action, source_project: source_project, source_package: source_package,
                                               target_project: target_project, target_package: target_package,
                                               creator: submitter)
      end

      it 'creates a BsRequest and supersede only the selected request(s)' do
        login submitter
        visit package_show_path(source_project, source_package)
        desktop? ? click_link('Submit Package') : click_menu_link('Actions', 'Submit Package')
        fill_in('To target project:', with: target_project.name)
        fill_in('To target package:', with: target_package.name)
        fill_in('bs_request_description', with: bs_request_description)

        expect(page).to have_text('Supersede requests:')
        expect(page).to have_all_of_selectors("#supersede_request_numbers#{bs_request_to_supersede.number}",
                                              "#supersede_request_numbers#{bs_request_to_supersede2.number}", visible: false)
        toggle_checkbox("supersede_request_numbers#{bs_request_to_supersede.number}")
        click_button('Submit')
        expect(page).to have_text("Submit package #{source_project} / #{source_package} " \
                                  "to package #{target_project} / #{target_package}")
        expect(page).to have_css('#description-text', text: bs_request_description)
        expect(page).to have_text('In state new')
        expect(page).to have_text("Supersedes #{bs_request_to_supersede.number}")
      end
    end

    describe 'submitting a package with a binary diff' do
      let(:source_package_with_binary) { create(:package_with_file, name: 'Toronto', project: source_project) }
      let(:target_package_with_binary) { create(:package_with_file, name: 'Toronto', project: target_project) }
      let(:bs_request) do
        create(:bs_request_with_submit_action,
               creator: submitter,
               target_project: target_project,
               target_package: target_package_with_binary,
               source_project: source_project,
               source_package: source_package_with_binary)
      end

      before do
        login submitter

        source_package_with_binary.save_file(filename: 'new_file.tar.gz', file: file_fixture('bigfile_archive.tar.gz').read)
        login receiver
        target_package_with_binary.save_file(filename: 'new_file.tar.gz', file: file_fixture('bigfile_archive_2.tar.gz').read)
        login submitter
      end

      it 'displays a diff' do
        visit request_show_path(bs_request)
        wait_for_ajax
        expect(page).to have_text('new_file.tar.gz/bigfile.txt')
      end
    end

    describe 'prefill form for a branched package' do
      let(:branched_package_name) { "#{target_package}_branch" }

      before do
        login submitter

        # TODO: Create a factory for this (branch a package and save a new file in it - to be able to submit the branched package)
        create(:branch_package,
               project: source_project.name,
               package: source_package.name,
               target_project: source_project.name,
               target_package: branched_package_name)
        Package.find_by(project_id: source_project.id, name: branched_package_name).save_file(filename: 'new_file', file: 'I am a new file')
      end

      it 'fills in the submission reasons and creates a BsRequest' do
        visit package_show_path(source_project, branched_package_name)
        desktop? ? click_link('Submit Package') : click_menu_link('Actions', 'Submit Package')
        expect(page).to have_field('To target project:', with: source_project.name)
        expect(page).to have_field('To target package:', with: source_package.name)
        fill_in('bs_request_description', with: bs_request_description)
        click_button('Submit')
        expect(page).to have_text("Submit package #{source_project} / #{branched_package_name} " \
                                  "to package #{source_project} / #{source_package}")
        expect(page).to have_css('#description-text', text: bs_request_description)
        expect(page).to have_text('In state new')
      end
    end

    describe 'when under the beta program', :beta do
      describe 'submit several packages at once against a factory staging project' do
        let!(:factory) { create(:project, name: 'openSUSE:Factory') }
        let!(:staging_workflow) { create(:staging_workflow, project: factory, commit_user: factory.commit_user) }
        # Create another action to submit new files from different packages to package_b
        let!(:another_bs_request_action) do
          receiver.run_as do
            create(:bs_request_action_submit,
                   bs_request: bs_request,
                   source_project: source_project,
                   source_package: source_package,
                   target_project: factory,
                   target_package: target_package_b)
          end
        end
        let(:bs_request) do
          create(:bs_request_with_submit_action,
                 creator: receiver,
                 target_project: factory,
                 target_package: target_package,
                 source_project: source_project,
                 source_package: source_package)
            .tap do |bs_request|
            bs_request.staging_project = staging_workflow.staging_projects.first
          end
        end
        let(:source_package) do
          create(:package_with_files,
                 name: 'package_a',
                 project: source_project,
                 changes_file_content: '- Fixes boo#1111101 CVE-2011-1101')
        end
        let(:target_package_b) { create(:package, name: 'package_b', project: factory) }

        it 'shows the beta version of the requests page' do
          login receiver
          visit request_show_path(bs_request.number)

          action = bs_request.bs_request_actions.first
          expect(page).to have_text("#{action.target_project} / #{action.target_package}")
          expect(page).to have_text('Next')
          expect(page).to have_text("(of #{bs_request.bs_request_actions.count})")
          expect(page).to have_css('.bg-staging')
        end
      end

      describe 'a request that has a diff comment' do
        let(:bs_request) do
          create(:bs_request_with_submit_action,
                 creator: receiver,
                 target_project: target_project,
                 target_package: target_package,
                 source_project: source_project,
                 source_package: source_package)
        end
        let!(:comment) { create(:comment, commentable: bs_request.bs_request_actions.first, diff_file_index: 0, diff_line_number: 1) }

        it 'displays the comment in the timeline' do
          login submitter
          visit request_show_path(bs_request)
          expect(page).to have_text(comment.body)
        end
      end

      describe 'a request that has a broken comment' do
        let(:bs_request) do
          create(:bs_request_with_submit_action,
                 creator: receiver,
                 target_project: target_project,
                 target_package: target_package,
                 source_project: source_project,
                 source_package: source_package)
        end
        let!(:comment) { create(:comment, commentable: bs_request) }

        it 'displays the comment in the timeline' do
          login submitter
          visit request_show_path(bs_request)
          expect(page).to have_text(comment.body)
        end
      end
    end
  end
end
