require 'rails_helper'
# WARNING: If you change owner tests make sure you uncomment this line
# and start a test backend. Some of the Owner methods
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe Webui::SearchController, vcr: true do
  let!(:user) { create(:confirmed_user, login: 'Iggy') }
  let!(:develuser) { create(:confirmed_user, login: 'DevelIggy') }
  let!(:package) { create(:package, name: 'TestPack', project: Project.find_by(name: 'home:Iggy')) }
  let!(:develpackage) { create(:package, name: 'DevelPack', project: Project.find_by(name: 'home:DevelIggy')) }
  let!(:owner_attrib) { create(:attrib, attrib_type: AttribType.where(name: "OwnerRootProject").first, project: Project.find_by(name: 'home:Iggy')) }

  describe "GET #owner" do
    it 'just returns with blank search text' do
      get(:owner, { search_text: '', owner: 1 })
      expect(response).to have_http_status(:success)
    end

    it 'warns about short search text' do
      get(:owner, { search_text: 'a', owner: 1 })
      expect(controller).to set_flash[:error].to("Search string must contain at least two characters.")
    end

    it 'assigns results' do
      get(:owner, { search_text: 'package', owner: 1 })
      expect(assigns(:results)[0].users).to eq({"maintainer"=>["Iggy"]})
    end

    it 'assigns results for devel package' do
      package.update_attributes(develpackage: develpackage)

      get(:owner, { search_text: 'package', owner: 1, devel: 'on' })
      expect(assigns(:results)[0].users).to eq({"maintainer"=>["DevelIggy"]})
      expect(assigns(:results)[0].users).not_to eq({"maintainer"=>["Iggy"]})
    end
  end
end
