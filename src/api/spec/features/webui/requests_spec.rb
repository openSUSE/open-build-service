require "browser_helper"

RSpec.feature "Requests", :type => :feature, :js => true do
  let!(:submitter) { create(:confirmed_user) }
  let!(:receiver) { create(:confirmed_user) }
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
        visit project_show_path(project: receiver.home_project_name)
        click_link 'Request role addition'
        find(:id, 'role').select('Bugowner')
        fill_in 'description', with: 'I can fix bugs too.'
        expect do
          click_button 'Ok'
        end.to change{ BsRequest.count }.by 1
        expect(page).to have_text("#{submitter.realname} (#{submitter.login}) wants the role bugowner for project #{receiver.home_project_name}")
        expect(page).to have_css("#description-text", text: "I can fix bugs too.")
        expect(page).to have_text('In state new')
      end

      it 'can be accepted' do
        new_action = create(:bs_request_action_add_bugowner_role, target_project: receiver.home_project_name, person_name: submitter)
        bs_request.bs_request_actions = [new_action]
        bs_request.save

        login receiver
        visit request_show_path(bs_request.id)
        click_button 'Accept'
        expect(page).to have_text("Request #{bs_request.id} (accepted)")
        expect(page).to have_text('In state accepted')
      end
    end
    describe 'for packages' do
      let(:package) { create(:package, project_id: Project.find_by(name: receiver.home_project_name).id ) }

      it 'can be submitted' do
        login submitter
        visit package_show_path(project: package.project, package: package)
        click_link 'Request role addition'
        find(:id, 'role').select('Maintainer')
        fill_in 'description', with: 'I can produce bugs too.'
        expect do
          click_button 'Ok'
        end.to change{ BsRequest.count }.by 1
        expect(page).to have_text("#{submitter.realname} (#{submitter.login}) wants the role maintainer \
                                   for package #{receiver.home_project_name} / #{package.name}")
        expect(page).to have_css("#description-text", text: "I can produce bugs too.")
        expect(page).to have_text('In state new')
      end
      it 'can be accepted' do
        new_action = create(:bs_request_action_add_maintainer_role, target_project: receiver.home_project_name,
                                                                    target_package: package.name,
                                                                    person_name: submitter)
        bs_request.bs_request_actions = [new_action]
        bs_request.save

        login receiver
        visit request_show_path(bs_request.id)
        click_button 'Accept'
        expect(page).to have_text("Request #{bs_request.id} (accepted)")
        expect(page).to have_text('In state accepted')
      end
    end
  end

  context 'accept request' do
    describe 'and add submitter as maintainer' do
      skip
    end
    describe 'not possible for own requests' do
      skip
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
