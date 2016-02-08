require "browser_helper"

RSpec.feature "Attributes", :type => :feature, :js => true do
  let!(:user) { create(:confirmed_user) }

  describe "attributes subtab" do
    let!(:package) {
      create(:package, project_id: Project.find_by_name(user.home_project_name).id)
    }
    let!(:attribute) { create(:attrib_type_with_namespace) }

    scenario "add attribute" do
      login user

      visit index_attribs_path(project: user.home_project_name, package: package.name)
      click_link("add-new-attribute")
      expect(page).to have_text("Add Attribute")
      find("select#attrib_attrib_type_id").select(attribute.name)
      click_button "Create Attribute"
      expect(page).to have_content("Attribute was successfully created.")
    end
  end

end
