require 'rails_helper'

RSpec.describe Webui::PackageController, vcr: true do
  let(:user) { create(:user, login: 'tom') }
  let(:source_project) { Project.find_by(name: user.home_project_name) }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }
  let(:target_project) { create(:project) }

  describe 'submit_request' do
    context 'not successful' do
      before do
        login(user)
        post :submit_request, { project: source_project, package: source_package, targetproject: target_project.name }
      end

      it { expect(flash[:error]).to eq('Unable to submit: The source of package home:tom/my_package is broken') }
      it { expect(BsRequestActionSubmit.where(target_project: target_project, target_package: source_package).count).to eq(0) }
    end
  end
end
