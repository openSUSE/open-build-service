RSpec.describe RequestDecisionComponent, :vcr, type: :component do
  let(:maintainer) { create(:confirmed_user, login: 'maintainer') }
  let(:target_project) { create(:project, name: 'target_project', maintainer: maintainer) }
  let(:target_package) { create(:package, name: 'target_package', project: target_project) }
  let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:devel_project) { create(:project, name: 'devel_project', maintainer: maintainer) }
  let(:devel_package) { create(:package, name: 'devel_package', project: devel_project) }
  let(:package_with_devel) { create(:package, name: 'package_with_devel', project: devel_project, develpackage: devel_package) }

  context 'when we cannot forward the request nor make the creator a maintainer' do
    let(:submit_request) do
      create(:bs_request_with_submit_action,
             creator: maintainer,
             target_package: target_package,
             source_package: source_package)
    end

    before do
      login maintainer
      render_inline(described_class.new(bs_request: submit_request,
                                        package_maintainers: submit_request.target_package_maintainers,
                                        show_project_maintainer_hint: true))
    end

    it { expect(submit_request.target_package_maintainers).to be_empty }

    it 'shows the Accept button as a regular button' do
      expect(rendered_content).to have_button('Accept request')
    end

    it 'does not show an option to make maintainer because the author is already a maintainer' do
      expect(rendered_content).to have_no_xpath(".//button/b[text()='Accept and make maintainer']")
    end

    it 'does not show an option to forward the request because there is no developed project' do
      expect(rendered_content).to have_no_xpath(".//button/b[text()='Accept and forward']")
    end
  end

  context 'when we can make request creator a maintainer of the target project' do
    let(:submit_request) do
      create(:bs_request_with_submit_action,
             target_package: target_package,
             source_package: source_package)
    end

    before do
      login maintainer
      render_inline(described_class.new(bs_request: submit_request,
                                        package_maintainers: submit_request.target_package_maintainers,
                                        show_project_maintainer_hint: true))
    end

    it 'shows the Accept button alternative options dropdown' do
      expect(rendered_content).to have_css('#request-accept-buttons-dropdown-menu')
    end

    it 'shows the Accept button as a regular button' do
      expect(rendered_content).to have_button('Accept request')
    end

    it 'shows an option to accept and make the creator a maintainer' do
      expect(rendered_content).to have_xpath(".//button/b[text()='Accept and make maintainer']")
    end

    it 'does not show an option to forward the request because there is no developed project' do
      expect(rendered_content).to have_no_xpath(".//button/b[text()='Accept and forward']")
    end
  end

  context 'when we can forward the request to the developed project' do
    let(:submit_request) do
      bs_request = create(:bs_request_with_submit_action,
                          creator: maintainer,
                          target_package: devel_package,
                          source_package: source_package)
      bs_request.bs_request_actions << create(:bs_request_action_submit,
                                              bs_request: bs_request,
                                              source_project: source_project,
                                              source_package: source_package,
                                              target_project: devel_project,
                                              target_package: package_with_devel)
      bs_request
    end

    before do
      login maintainer
      render_inline(described_class.new(bs_request: submit_request,
                                        package_maintainers: submit_request.target_package_maintainers,
                                        show_project_maintainer_hint: true))
    end

    it 'shows the Accept button alternative options dropdown' do
      expect(rendered_content).to have_css('#request-accept-buttons-dropdown-menu')
    end

    it 'shows the Accept button as a regular button' do
      expect(rendered_content).to have_button('Accept request')
    end

    it 'shows an option to accept and forward the request' do
      expect(rendered_content).to have_xpath(".//button/b[text()='Accept and forward']")
    end

    it 'does not show an option to make maintainer because the author is already a maintainer' do
      expect(rendered_content).to have_no_xpath(".//button/b[text()='Accept and make maintainer']")
    end
  end

  context 'when we can forward the request and make the creator a maintainer' do
    let(:submit_request) do
      bs_request = create(:bs_request_with_submit_action,
                          target_package: devel_package,
                          source_package: source_package)
      bs_request.bs_request_actions << create(:bs_request_action_submit,
                                              bs_request: bs_request,
                                              source_project: source_project,
                                              source_package: source_package,
                                              target_project: devel_project,
                                              target_package: package_with_devel)
      bs_request
    end

    before do
      login maintainer
      render_inline(described_class.new(bs_request: submit_request,
                                        package_maintainers: submit_request.target_package_maintainers,
                                        show_project_maintainer_hint: true))
    end

    it 'shows the Accept button alternative options dropdown' do
      expect(rendered_content).to have_css('#request-accept-buttons-dropdown-menu')
    end

    it 'shows the Accept button as a regular button' do
      expect(rendered_content).to have_button('Accept request')
    end

    it 'shows an option to accept and make the creator a maintainer' do
      expect(rendered_content).to have_xpath(".//button/b[text()='Accept and make maintainer']")
    end

    it 'shows an option to accept and forward the request' do
      expect(rendered_content).to have_xpath(".//button/b[text()='Accept and forward']")
    end

    it 'shows an option to accept, make the creator a maintainer and forward the request' do
      expect(rendered_content).to have_xpath(".//button/b[text()='Accept, make maintainer and forward']")
    end
  end
end
