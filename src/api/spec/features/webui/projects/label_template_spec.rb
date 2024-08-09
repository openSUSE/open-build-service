require 'browser_helper'

RSpec.describe 'LabelTemplates', :js, :vcr do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }

  before do
    Flipper.enable(:labels)

    login user
  end

  context 'when having no label templates' do
    it 'creates a label template' do
      visit project_label_templates_path(project)

      click_on('Create Label Template')
      fill_in('Name', with: 'A label template')
      click_on('Create')

      expect(LabelTemplate.last.name).to eql('A label template')
    end
  end

  context 'when having an already existing label template' do
    let!(:label_template) { create(:label_template, project: project) }

    it 'updates an already existing label template' do
      visit project_label_templates_path(project)

      click_on('Edit')
      fill_in('Name', with: 'A label template updated')
      click_on('Update')

      expect(label_template.reload.name).to eql('A label template updated')
    end

    it 'deletes an already existing label template' do
      visit project_label_templates_path(project)

      accept_confirm { click_on('Delete') }
      expect(page).to have_text('Label template deleted successfully')
    end
  end
end
