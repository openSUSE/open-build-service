require "browser_helper"
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the BsRequestAction methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.feature "Requests", :type => :feature, :js => true do
  let!(:submitter) { create(:confirmed_user, login: 'kugelblitz' ) }
  let!(:receiver) { create(:confirmed_user, login: 'titan' ) }
  let(:target_project) { Project.find_by(name: receiver.home_project_name) }
  let!(:target_package) { create(:package, name: 'goal', project_id: target_project.id) }
  let(:source_project) { Project.find_by(name: submitter.home_project_name) }
  let!(:source_package) { create(:package, name: 'ball', project_id: source_project.id) }
  let!(:bs_request) { create(:bs_request, description: "a long text - " * 200, creator: submitter.login) }

  RSpec.shared_examples "expandable element" do
    scenario "expanding a text field" do
      invalid_word_count = valid_word_count + 1

      visit request_show_path(bs_request)
      within(element) do
        expect(page).to have_text("a long text - " * valid_word_count)
        expect(page).not_to have_text("a long text - " * invalid_word_count)

        click_link("[+]")
        expect(page).to have_text("a long text - "* 200)

        click_link("[-]")
        expect(page).to have_text("a long text - " * valid_word_count)
        expect(page).not_to have_text("a long text - " * invalid_word_count)
      end
    end
  end

  context "request show page" do
    describe "request description field" do
      it_behaves_like "expandable element" do
        let(:element) { "pre#description-text" }
        let(:valid_word_count) { 21 }
      end
    end

    describe "request history entries" do
      it_behaves_like "expandable element" do
        let(:element) { ".expandable_event_comment" }
        let(:valid_word_count) { 3 }
      end
    end
  end

  context 'for role addition' do
    describe 'for projects' do
      it 'can be submitted' do
        login submitter
        visit project_show_path(project: target_project)
        click_link 'Request role addition'
        find(:id, 'role').select('Bugowner')
        fill_in 'description', with: 'I can fix bugs too.'
        expect do
          click_button 'Ok'
        end.to change{ BsRequest.count }.by 1
        expect(page).to have_text("#{submitter.realname} (#{submitter.login}) wants the role bugowner for project #{target_project}")
        expect(page).to have_css("#description-text", text: "I can fix bugs too.")
        expect(page).to have_text('In state new')
      end

      it 'can be accepted' do
        bs_request.bs_request_actions.delete_all
        create(:bs_request_action_add_bugowner_role, target_project: target_project.name,
                                                     person_name: submitter,
                                                     bs_request_id: bs_request.id)

        login receiver
        visit request_show_path(bs_request.id)
        click_button 'Accept'
        expect(page).to have_text("Request #{bs_request.id} (accepted)")
        expect(page).to have_text('In state accepted')
      end
    end
    describe 'for packages' do
      it 'can be submitted' do
        login submitter
        visit package_show_path(project: target_project, package: target_package)
        click_link 'Request role addition'
        find(:id, 'role').select('Maintainer')
        fill_in 'description', with: 'I can produce bugs too.'
        expect do
          click_button 'Ok'
        end.to change{ BsRequest.count }.by 1
        expect(page).to have_text("#{submitter.realname} (#{submitter.login}) wants the role maintainer \
                                   for package #{target_project} / #{target_package}")
        expect(page).to have_css("#description-text", text: "I can produce bugs too.")
        expect(page).to have_text('In state new')
      end
      it 'can be accepted' do
        bs_request.bs_request_actions.delete_all
        create(:bs_request_action_add_maintainer_role, target_project: target_project.name,
                                                       target_package: target_package.name,
                                                       person_name: submitter,
                                                       bs_request_id: bs_request.id)
        login receiver
        visit request_show_path(bs_request.id)
        click_button 'Accept'
        expect(page).to have_text("Request #{bs_request.id} (accepted)")
        expect(page).to have_text('In state accepted')
      end
    end
  end

  describe 'accept' do
    it 'can add submitter as maintainer' do
      bs_request.bs_request_actions.delete_all
      create(:bs_request_action_submit, target_project: target_project.name,
                                        target_package: source_package.name,
                                        source_project: source_project.name,
                                        source_package: source_package.name,
                                        bs_request_id: bs_request.id)

      login receiver
      visit request_show_path(bs_request.id)
      check 'add_submitter_as_maintainer_0'
      click_button 'Accept request'
      expect(page).to have_text("Request #{bs_request.id} (accepted)")
      expect(page).to have_text('In state accepted')
      expect(submitter.has_local_permission?('change_package', target_project.packages.find_by(name: source_package.name))).to be_truthy
    end
  end

  describe 'superseeding' do
    skip
  end

  describe 'revoking' do
    skip
  end

  context 'commenting' do
    describe 'start thread' do
      skip
    end
    describe 'reply' do
      skip
    end
    describe 'mail notifications' do
      skip
    end
  end

  context 'reviews' do
    describe 'for user' do
      skip
    end
    describe 'for group' do
      skip
    end
    describe 'for project' do
      skip
    end
    describe 'for invalid project' do
      skip
    end
    describe 'for package' do
      skip
    end
  end
end
