require 'browser_helper'

RSpec.describe 'LabelTemplates', :js, :vcr do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
  let(:project) { user.home_project }

  before do
    Flipper.enable(:labels)

    login user
  end

  context 'having no label templates' do
    before do
      visit project_label_templates_path(project)
    end

    it 'creates a label template' do
      click_on('Create Label Template')
      fill_in('Name', with: 'A label template')
      click_on('Create')

      expect(page).to have_text('Label template created successfully')
      expect(LabelTemplate.where(name: 'A label template')).to exist
    end
  end

  context 'having an already existing label template' do
    let!(:label_template) { create(:label_template, project: project) }

    context 'edit a label template' do
      before do
        visit project_label_templates_path(project)

        click_on('Edit')
        fill_in('Name', with: 'A label template updated')
        click_on('Update')
      end

      it 'updates an already existing label template' do
        expect(page).to have_text('Label template updated successfully')
        expect(label_template.reload.name).to eq('A label template updated')
      end
    end

    it 'deletes an already existing label template' do
      visit project_label_templates_path(project)

      accept_confirm { click_on('Delete') }
      expect(page).to have_text('Label template deleted successfully')
    end

    context 'copying label templates to another project' do
      let(:another_project) { create(:project, maintainer: user) }

      before do
        visit project_label_templates_path(another_project)

        click_on('Copy from Another Project')
        fill_in('Source Project', with: project.name)
        click_on('Copy')
      end

      it 'copies all the label templates' do
        expect(page).to have_text(project.label_templates.first.name)
      end
    end
  end
end
