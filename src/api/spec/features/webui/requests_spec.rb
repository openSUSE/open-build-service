require "browser_helper"
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the BsRequestAction methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.feature "Requests", :type => :feature, :js => true do
  let(:submitter) { create(:confirmed_user, login: 'kugelblitz' ) }
  let(:receiver) { create(:confirmed_user, login: 'titan' ) }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package, name: 'goal', project_id: target_project.id) }
  let(:source_project) { submitter.home_project }
  let(:source_package) { create(:package, name: 'ball', project_id: source_project.id) }
  let(:bs_request) { create(:bs_request, description: "a long text - " * 200, creator: submitter.login) }
  let(:create_submit_request) do
    bs_request.bs_request_actions.delete_all
    create(:bs_request_action_submit, target_project: target_project.name,
                                      target_package: source_package.name,
                                      source_project: source_project.name,
                                      source_package: source_package.name,
                                      bs_request_id: bs_request.id)
  end

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

        expect { click_button 'Ok' }.to change{ BsRequest.count }.by 1
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
        visit request_show_path(bs_request)
        click_button 'Accept'

        expect(page).to have_text("Request #{bs_request.number} (accepted)")
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

        expect { click_button 'Ok' }.to change{ BsRequest.count }.by 1
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
        visit request_show_path(bs_request)
        click_button 'Accept'

        expect(page).to have_text("Request #{bs_request.number} (accepted)")
        expect(page).to have_text('In state accepted')
      end
    end
  end

  describe 'accept' do
    it 'can add submitter as maintainer' do
      create_submit_request
      login receiver
      visit request_show_path(bs_request)
      check 'add_submitter_as_maintainer_0'
      click_button 'Accept request'

      expect(page).to have_text("Request #{bs_request.number} (accepted)")
      expect(page).to have_text('In state accepted')
      expect(submitter.has_local_permission?('change_package', target_project.packages.find_by(name: source_package.name))).to be_truthy
    end
  end

  describe 'superseed' do
    it 'other requests' do
      create_submit_request
      Suse::Backend.put("/source/#{source_package.project.name}/#{source_package.name}/somefile.txt", Faker::Lorem.paragraph)
      login submitter
      visit package_show_path(project: source_project, package: source_package)
      click_link 'Submit package'
      fill_in 'targetproject', with: target_project.name
      fill_in 'description', with: 'Testing superseeding'
      check("supersede_request_numbers#{bs_request.number}")
      click_button 'Ok'
      within '#flash-messages' do
        click_link 'submit request'
      end

      expect(page).to have_text("Supersedes #{bs_request.number}")
    end
  end

  describe 'revoke' do
    it 'revokes request' do
      create_submit_request
      login submitter
      visit request_show_path(bs_request)
      fill_in 'reason', with: 'Oops'
      click_button 'Revoke request'

      expect(page).to have_text('Request revoked!')
      expect(page).to have_text("Request #{bs_request.number} (revoked)")
      expect(page).to have_text("There's nothing to be done right now")
    end
  end

  describe 'decline' do
    let(:maintainer) { create(:confirmed_user) }
    let!(:relationship) { create(:relationship, project: target_project, user: maintainer) }

    it 'maintainer declines request' do
      create_submit_request
      login maintainer
      visit request_show_path(bs_request)
      fill_in 'reason', with: "Don't like it:("
      click_button 'Decline request'

      expect(page).to have_text('Request declined!')
      expect(page).to have_text("Request #{bs_request.number} (declined)")

      bs_request.reload
      expect(bs_request.state).to eq(:declined)
      expect(bs_request.comment).to eq("Don't like it:(")
      expect(bs_request.commenter).to eq(maintainer.login)
    end
  end

  context 'review' do
    describe 'for user' do
      let(:reviewer) { create(:confirmed_user) }
      it 'opens a review' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a review'
        find(:id, 'review_type').select('User')
        fill_in 'review_user', with: reviewer.login
        click_button 'Ok'
        expect(page).to have_text("Open review for #{reviewer.login}")
      end
    end

    describe 'for group' do
      let(:review_group) { create(:group) }
      it 'opens a review' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a review'
        find(:id, 'review_type').select('Group')
        fill_in 'review_group', with: review_group.title
        click_button 'Ok'
        expect(page).to have_text("Open review for #{review_group.title}")
      end
    end

    describe 'for project' do
      it 'opens a review' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a review'
        find(:id, 'review_type').select('Project')
        fill_in 'review_project', with: submitter.home_project
        click_button 'Ok'
        expect(page).to have_text("Review for #{submitter.home_project}")
      end
    end

    describe 'for package' do
      let(:package) { create(:package, project: submitter.home_project) }
      it 'opens a review' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a review'
        find(:id, 'review_type').select('Package')
        fill_in 'review_project', with: submitter.home_project
        fill_in 'review_package', with: package.name
        click_button 'Ok'
        expect(page).to have_text("Review for #{submitter.home_project} / #{package.name}")
      end
    end

    describe 'for invalid reviewer' do
      it 'opens no review' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a review'
        find(:id, 'review_type').select('Project')
        fill_in 'review_project', with: 'INVALID/PROJECT'
        click_button 'Ok'
        expect(page).to have_css("#flash-messages", text: "Unable add review to")
      end
    end
  end
end
