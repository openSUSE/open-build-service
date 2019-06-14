require 'browser_helper'

RSpec.feature 'Repositories', type: :feature, js: true do
  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project) }
  let!(:relationship) { create(:relationship_project_user, project: project, user: user) }

  let(:my_project) { create(:project, name: 'MyProject') }
  let!(:repository) { create(:repository, name: 'standard', project: my_project) }
  let!(:distribution) { create(:distribution, project: my_project, repository: 'standard') }

  scenario 'add' do
    skip_unless_bento

    login user
    visit "/project/add_repository_from_default_list/#{project.name}"

    find("label[for='repo_#{distribution.reponame}']").click

    expect(page).to have_text("Successfully added repository '#{distribution.reponame}'")
  end
end
