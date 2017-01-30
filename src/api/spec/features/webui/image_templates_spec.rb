require "browser_helper"
# WARNING: This test require real backend answers for projects/packages, make
# sure you uncomment this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.feature "ImageTemplates", type: :feature, js: true do
  let(:admin) { create(:admin_user, login: 'admin') }

  context "branching" do
    let(:project) { create(:project, name: "my_project") }
    let!(:attrib) { create(:template_attrib, project: project) }
    let!(:package1) { create(:package_with_file, project: project, name: "first_package") }
    let!(:package2) { create(:package_with_file, project: project, name: "second_package") }

    scenario "branch image template" do
      login(admin)

      visit root_path
      find('.proceed_text > a', text: "New Image").click

      expect(page).to have_text(package1)
      expect(find("input[data-package='#{package1}']", visible: false)['checked']).to be true
      expect(find("input[data-package='#{package2}']", visible: false)['checked']).to be false

      expect(page).to have_field('target_package', with: package1)
      find("input[data-package='#{package2}']", visible: false).trigger(:click)
      expect(page).to have_field('target_package', with: package2)
      fill_in 'target_package', with: "custom_name"

      click_button("Create appliance")
      expect(page).to have_text("Successfully branched package")
      expect(page).to have_text("home:admin:branches:my_project > custom_name")
    end
  end

  context 'feature switch' do
    before do
      login admin
    end

    scenario 'enabled' do
      Feature.run_with_activated(:image_templates) do
        visit root_path
        expect(page).to have_link("New Image")
      end
    end

    scenario 'disabled' do
      Feature.run_with_deactivated(:image_templates) do
        visit root_path
        expect(page).not_to have_link("New Image")
      end
    end
  end
end
