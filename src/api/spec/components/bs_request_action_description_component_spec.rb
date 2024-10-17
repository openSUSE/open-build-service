RSpec.describe BsRequestActionDescriptionComponent, type: :component do
  context 'when testing the previews' do
    let(:user) { create(:confirmed_user, :with_home) }
    let(:creator) { create(:confirmed_user, login: 'creator', realname: 'Creator') }
    let(:source_prj) { create(:project) }
    let(:source_pkg) { create(:package, project: source_prj) }
    let(:target_prj) { user.home_project }
    let(:target_pkg) { create(:package, project: target_prj) }

    context 'when previewing the submit request action' do
      let!(:bs_request) do
        create(:bs_request, type: 'submit', source_package: source_pkg, source_project: source_prj, target_project: target_prj, target_package: target_pkg, creator: user)
      end

      before { render_preview(:submit_preview) }

      it { expect(rendered_content).to have_text("Submit package #{source_prj} / #{source_pkg} to package #{target_prj} / #{target_pkg}") }
    end

    context 'when previewing the add role request action' do
      let!(:bs_request) { create(:bs_request, type: :add_role, target_project: user.home_project, role: 'maintainer', person_name: user.login, creator: creator) }

      before { render_preview(:add_role_preview) }

      it { expect(rendered_content).to have_text("Creator (creator) wants the user #{user.name} (#{user.login}) to get the role maintainer for project #{user.home_project}") }
    end
  end
end
