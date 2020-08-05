require 'browser_helper'

RSpec.describe 'Bootstrap_Requests_Submissions', type: :feature, js: true, vcr: true do
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
        expect(page).to have_text("Submit package #{source_project} / #{source_package} "\
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
        expect(page).to have_text("Submit package #{source_project} / #{source_package} "\
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
      let!(:bs_request_to_supersede_2) do
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
                                              "#supersede_request_numbers#{bs_request_to_supersede_2.number}", visible: false)
        toggle_checkbox("supersede_request_numbers#{bs_request_to_supersede.number}")
        click_button('Submit')
        expect(page).to have_text("Submit package #{source_project} / #{source_package} "\
                                  "to package #{target_project} / #{target_package}")
        expect(page).to have_css('#description-text', text: bs_request_description)
        expect(page).to have_text('In state new')
        expect(page).to have_text("Supersedes #{bs_request_to_supersede.number}")
      end
    end

    describe 'prefill form for a branched package' do
      let(:branched_package_name) { "#{target_package}_branch" }

      before do
        login submitter

        # TODO: Create a factory for this (branch a package and save a new file in it - to be able to submit the branched package)
        BranchPackage.new(
          project: source_project.name,
          package: source_package.name,
          target_project: source_project.name,
          target_package: branched_package_name
        ).branch
        Package.find_by(project_id: source_project.id, name: branched_package_name).save_file(filename: 'new_file', file: 'I am a new file')
      end

      it 'fills in the submission reasons and creates a BsRequest' do
        visit package_show_path(source_project, branched_package_name)
        desktop? ? click_link('Submit Package') : click_menu_link('Actions', 'Submit Package')
        expect(page).to have_field('To target project:', with: source_project.name)
        expect(page).to have_field('To target package:', with: source_package.name)
        fill_in('bs_request_description', with: bs_request_description)
        click_button('Submit')
        expect(page).to have_text("Submit package #{source_project} / #{branched_package_name} "\
                                  "to package #{source_project} / #{source_package}")
        expect(page).to have_css('#description-text', text: bs_request_description)
        expect(page).to have_text('In state new')
      end
    end
  end
end
