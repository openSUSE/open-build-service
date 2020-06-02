require 'browser_helper'

RSpec.describe 'Bootstrap_ChangeBugowner', type: :feature, js: true do
  let!(:bugowner) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let!(:package) { create(:package, name: 'TestPack', project: project) }
  let(:project) { Project.find_by(name: 'home:Iggy') }
  let!(:new_bugowner) { create(:confirmed_user, :with_home, login: 'Milo') }
  let!(:group) { create(:group, title: 'Heroes') }

  let!(:collection) do
    file_fixture('owner_search_collection.xml').read
  end
  let!(:bug_collection) do
    file_fixture('owner_search_bugownership_collection.xml').read
  end

  before do
    login bugowner
    create(:attrib, attrib_type: AttribType.where(name: 'OwnerRootProject').first, project: Project.find_by(name: 'home:Iggy'))
    create(:relationship_package_user, package: package, user: bugowner, role: Role.find_by_title('bugowner'))
    allow(Backend::Api::Search).to receive(:binary).and_return(collection)

    visit search_owner_path
    fill_in :search_input, with: package.name
    click_button 'Search'
    click_link 'Request bugowner change'
  end

  context 'with a user as new bugowner' do
    it 'the bugowner is changed' do
      fill_in :user, with: 'Milo'
      fill_in :description, with: 'Replace current bugowner by Milo'
      click_button 'Submit'
      expect(page).to have_text("#{bugowner.name} (#{bugowner.login}) wants the user #{new_bugowner.name} (#{new_bugowner.login}) to become bugowner (previous bugowners will be deleted)")
    end
  end

  context 'with a group as new bugowner' do
    it 'the bugowner is changed by a group' do
      find(:id, 'review_type').select('Group')
      fill_in :group, with: 'Heroes'
      fill_in :description, with: 'Replace current bugowner by group Heroes'
      click_button 'Submit'
      expect(page).to have_text("#{bugowner.name} (#{bugowner.login}) wants the group #{group.title} to become bugowner (previous bugowners will be deleted)")
    end
  end

  context 'forcing to add both user and group as bugowner' do
    it 'only the visible one before submitting is added' do
      find(:id, 'review_type').select('Group')
      fill_in :group, with: 'Heroes'
      find(:id, 'review_type').select('User')
      fill_in :user, with: 'Milo'
      fill_in :description, with: 'Replace current bugowner by something else'
      click_button 'Submit'
      expect(page).to have_text("#{bugowner.name} (#{bugowner.login}) wants the user #{new_bugowner.name} (#{new_bugowner.login}) to become bugowner (previous bugowners will be deleted)")
      expect(page).not_to have_text('Heroes')
    end
  end
end
