require 'browser_helper'

RSpec.feature 'Bootstrap_Requests', type: :feature, js: true, vcr: true do
  let(:submitter) { create(:confirmed_user, login: 'kugelblitz') }
  let(:receiver) { create(:confirmed_user, login: 'titan') }
  let(:target_project) { receiver.home_project }
  let(:target_package) { create(:package, name: 'goal', project_id: target_project.id) }
  let(:source_project) { submitter.home_project }
  let(:source_package) { create(:package, name: 'ball', project_id: source_project.id) }
  let(:bs_request) { create(:delete_bs_request, target_project: target_project, description: 'a long text - ' * 200, creator: submitter) }

  RSpec.shared_examples 'expandable element' do
    scenario 'expanding a text field' do
      visit request_show_path(bs_request)
      within(element) do
        # FIXME: find a better way to check if the content is collapsed or not
        find(id: 'show-full-req-description').click
        expect(find(id: 'req-description').native.css_value('max-height')).to eq('none')
        find(id: 'show-full-req-description').click
        expect(find(id: 'req-description').native.css_value('max-height')).not_to eq('none')
      end
    end
  end

  context 'request show page' do
    let!(:superseded_bs_request) { create(:superseded_bs_request, superseded_by_request: bs_request) }
    let!(:comment_1) { create(:comment, commentable: bs_request) }
    let!(:comment_2) { create(:comment, commentable: superseded_bs_request) }

    scenario 'show request comments' do
      visit request_show_path(bs_request)
      expect(page).to have_text(comment_1.body)
      expect(page).not_to have_text(comment_2.body)
      find('a', text: "Comments for request #{superseded_bs_request.number}").click
      expect(page).to have_text(comment_2.body)
      expect(page).not_to have_text(comment_1.body)
    end

    describe 'request description field' do
      skip('Te overview doesn\'t have the new collapse feature') do
        it_behaves_like 'expandable element' do
          let(:element) { 'pre#description-text' }
        end
      end
    end

    describe 'request history entries' do
      it_behaves_like 'expandable element' do
        let(:element) { '.req-description-box' }
      end
    end
  end

  context 'for role addition' do
    describe 'for projects' do
      it 'can be submitted' do
        login submitter
        visit project_show_path(project: target_project)
        click_link('Request Role Addition')
        find(:id, 'role').select('Bugowner')
        fill_in 'description', with: 'I can fix bugs too.'

        expect { click_button('Accept') }.to change(BsRequest, :count).by(1)
        expect(page).to have_text("#{submitter.realname} (#{submitter.login}) wants to get the role bugowner for project #{target_project}")
        expect(page).to have_css('#description-text', text: 'I can fix bugs too.')
        expect(page).to have_text('In state new')
      end

      it 'can be accepted' do
        bs_request.bs_request_actions.delete_all
        create(:bs_request_action_add_bugowner_role, target_project: target_project,
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
      let(:bs_request) do
        create(:add_maintainer_request, target_package: target_package,
                                        description: 'a long text - ' * 200,
                                        creator: submitter,
                                        person_name: submitter)
      end
      it 'can be submitted' do
        login submitter
        visit package_show_path(project: target_project, package: target_package)
        click_link 'Request role addition'
        within('#add-role-modal') do
          find(:id, 'role').select('Maintainer')
          fill_in 'description', with: 'I can produce bugs too.'
          expect { click_button('Accept') }.to change(BsRequest, :count).by(1)
        end
        expect(page).to have_text("#{submitter.realname} (#{submitter.login}) wants to get the role maintainer " \
                                  "for package #{target_project} / #{target_package}")
        expect(page).to have_css('#description-text', text: 'I can produce bugs too.')
        expect(page).to have_text('In state new')
      end

      it 'can be accepted' do
        login receiver
        visit request_show_path(bs_request)
        click_button 'Accept'

        expect(page).to have_text("Request #{bs_request.number} (accepted)")
        expect(page).to have_text('In state accepted')
      end
    end
  end

  context 'review' do
    describe 'for user' do
      let(:reviewer) { create(:confirmed_user) }

      it 'opens a review and accepts it' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a Review'
        find(:id, 'review_type').select('User')
        fill_in 'review_user', with: reviewer.login
        click_button('Accept')
        expect(page).to have_text(/Open review for\s+#{reviewer.login}/)
        expect(page).to have_text('Request 1 (review)')
        expect(Review.all.count).to eq(1)
        logout

        login reviewer
        visit request_show_path(1)
        click_link("Review for #{submitter}")
        fill_in 'comment', with: 'Ok for the project'
        click_button 'Approve'
        expect(page).to have_text('Ok for the project')
        expect(Review.first.state).to eq(:accepted)
        expect(BsRequest.first.state).to eq(:new)
      end
    end

    describe 'for group' do
      let(:review_group) { create(:group) }
      it 'opens a review' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a Review'
        find(:id, 'review_type').select('Group')
        fill_in 'review_group', with: review_group.title
        click_button('Accept')
        expect(page).to have_text("Open review for #{review_group.title}")
      end
    end

    describe 'for project' do
      it 'opens a review' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a Review'
        find(:id, 'review_type').select('Project')
        fill_in 'review_project', with: submitter.home_project
        click_button('Accept')
        expect(page).to have_text("Open review for #{submitter.home_project}")
      end
    end

    describe 'for package' do
      let(:package) { create(:package, project: submitter.home_project) }
      it 'opens a review' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a Review'
        find(:id, 'review_type').select('Package')
        fill_in 'review_project', with: submitter.home_project
        fill_in 'review_package', with: package.name
        click_button('Accept')
        expect(page).to have_text("Open review for #{submitter.home_project} / #{package.name}")
      end
    end

    describe 'for invalid reviewer' do
      it 'opens no review' do
        login submitter
        visit request_show_path(bs_request)
        click_link 'Add a Review'
        find(:id, 'review_type').select('Project')
        fill_in 'review_project', with: 'INVALID/PROJECT'
        click_button('Accept')
        expect(page).to have_css('#flash', text: 'Unable add review to')
      end
    end
  end

  describe 'shows the correct auto accepted message' do
    before do
      bs_request.accept_at = Time.now
      bs_request.save
    end

    scenario 'when request is in a final state' do
      bs_request.state = :accepted
      bs_request.save
      visit request_show_path(bs_request)
      expect(page).to have_text("Auto-accept was set to #{I18n.localize bs_request.accept_at, format: :only_date}.")
    end

    scenario 'when request auto_accept is in the past and not in a final state' do
      visit request_show_path(bs_request)
      expect(page).to have_text("This request will be automatically accepted when it enters the 'new' state.")
    end

    scenario 'when request auto_accept is in the future and not in a final state' do
      bs_request.accept_at = Time.now + 1.day
      bs_request.save
      visit request_show_path(bs_request)
      expect(page).
        to have_text("This request will be automatically accepted in #{ApplicationController.helpers.time_ago_in_words(bs_request.accept_at)}.")
    end
  end
end
