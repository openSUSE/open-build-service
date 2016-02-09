require "browser_helper"

RSpec.feature "Attributes", :type => :feature, :js => true do
  let!(:user) { create(:confirmed_user) }

  describe "attributes subtab" do
    let!(:package) {
      create(:package, project_id: Project.find_by_name(user.home_project_name).id)
    }
    let!(:attribute) { create(:attrib_type_with_namespace) }

    scenario "add attribute with values" do
      login user

      visit index_attribs_path(project: user.home_project_name, package: package.name)
      click_link("add-new-attribute")
      expect(page).to have_text("Add Attribute")
      find("select#attrib_attrib_type_id").select(attribute.name)
      click_button "Create Attribute"
      expect(page).to have_content("Attribute was successfully created.")

      # Add two values
      click_link "add value"
      click_link "add value"

      fill_in "Value", with: "test 1", :match => :first
      # Workaround to enter data into second textfield
      within("div.nested-fields:nth-of-type(2)") do
        fill_in "Value", with: "test 2"
      end

      click_button "Save Attribute"
      expect(page).to have_content("Attribute was successfully updated.")

      visit index_attribs_path(project: user.home_project_name, package: package.name)
      within("tr.attribute-values") do
        expect(page).to have_content("#{attribute.namespace}:#{attribute.name} test 2, test 1")
      end
    end
  end

end
