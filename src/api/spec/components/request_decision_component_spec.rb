RSpec.describe RequestDecisionComponent, :vcr, type: :component do
  context 'when we cannot forward the request nor make the creator a maintainer' do
    let(:maintainer) { create(:confirmed_user) }
    let(:target_project) { create(:project, name: 'target_project', maintainer: maintainer) }
    let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
    let(:target_package) { create(:package, name: 'target_package', project: target_project) }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }
    let(:submit_request) do
      create(:bs_request_with_submit_action,
             target_package: target_package,
             source_package: source_package)
    end
    let(:actions) { submit_request.bs_request_actions }
    let(:action) { actions.first }
    let(:package_maintainers) do
      distinct_bs_request_actions = actions.select(:target_project, :target_package).distinct
      distinct_bs_request_actions.flat_map do |action|
        Package.find_by_project_and_name(action.target_project, action.target_package).try(:maintainers)
      end.compact.uniq
    end

    before do
      User.session = maintainer
      render_inline(described_class.new(bs_request: submit_request, action: action, is_target_maintainer: true, package_maintainers: package_maintainers, show_project_maintainer_hint: true))
    end

    it { expect(package_maintainers).to be_empty }

    it 'shows the Accept button as a regular button' do
      expect(rendered_content).to have_button('Accept')
    end
  end

  context 'when we can make request creator a maintainer of the target project' do
    let(:maintainer) { create(:confirmed_user) }
    let(:target_project) { create(:project, name: 'target_project', maintainer: maintainer) }
    let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
    let(:target_package) { create(:package, name: 'target_package', project: target_project) }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }
    let(:submit_request) do
      create(:bs_request_with_submit_action,
             target_package: target_package,
             source_package: source_package)
    end
    let(:actions) { submit_request.bs_request_actions }
    let(:action) { actions.first }
    let(:package_maintainers) do
      distinct_bs_request_actions = actions.select(:target_project, :target_package).distinct
      distinct_bs_request_actions.flat_map do |action|
        Package.find_by_project_and_name(action.target_project, action.target_package).try(:maintainers)
      end.compact.uniq
    end

    before do
      User.session = maintainer
      render_inline(described_class.new(bs_request: submit_request, action: action, is_target_maintainer: true, package_maintainers: package_maintainers, show_project_maintainer_hint: true))
    end

    it 'shows the Accept button as a dropdown' do
      expect(rendered_content).to have_button(id: 'decision-buttons-group')
    end

    it 'shows an option to accept the request only' do
      expect(rendered_content).to have_css('input[value="Accept request"]')
    end

    it 'shows an option to accept and make the creator a maintainer' do
      expect(rendered_content).to have_css("input[value='Accept and make #{submit_request.creator} maintainer of target_project/target_package']")
    end
  end

  context 'when we can forward the request to the developed project' do
    let(:maintainer) { create(:confirmed_user) }
    let(:target_project) { create(:project, name: 'target_project') }
    let(:target_package) { create(:package, name: 'target_package', project: target_project) }
    let(:another_target_project) { create(:project, name: 'another_target_project') }
    let(:another_target_package) { create(:package, name: 'another_target_package', project: another_target_project) }
    let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }
    let(:devel_project1) { create(:project, name: 'devel_project1', maintainer: maintainer) }
    let(:devel_package1) { create(:package, name: 'devel_package1', project: devel_project1) }
    let(:submit_request) do
      create(:bs_request_with_submit_action,
             creator: maintainer,
             target_package: devel_package1,
             source_package: source_package)
    end
    let(:actions) { submit_request.bs_request_actions }
    let(:action) { actions.first }
    let(:package_maintainers) do
      distinct_bs_request_actions = actions.select(:target_project, :target_package).distinct
      distinct_bs_request_actions.flat_map do |action|
        Package.find_by_project_and_name(action.target_project, action.target_package).try(:maintainers)
      end.compact.uniq
    end

    before do
      another_action = submit_request.bs_request_actions.last
      another_action.target_project_object = another_target_project
      another_action.target_package_object = another_target_package
      another_action.save!
      target_package.update(develpackage: devel_package1)
      another_target_package.update(develpackage: devel_package1)
      User.session = maintainer
      render_inline(described_class.new(bs_request: submit_request, action: action, is_target_maintainer: true, package_maintainers: package_maintainers, show_project_maintainer_hint: true))
    end

    it 'shows the Accept button as a dropdown' do
      expect(rendered_content).to have_button(id: 'decision-buttons-group')
    end

    it 'shows an option to accept the request only' do
      expect(rendered_content).to have_css('input[value="Accept request"]')
    end

    it 'shows an option to accept and forward the request' do
      expect(rendered_content).to have_css("input[value='Accept and forward submit request to #{another_target_project}/#{another_target_package} and #{target_project}/#{target_package}']")
    end
  end

  context 'when we can forward the request and make the creator a maintainer' do
    let(:maintainer) { create(:confirmed_user) }
    let(:target_project) { create(:project, name: 'target_project') }
    let(:target_package) { create(:package, name: 'target_package', project: target_project) }
    let(:another_target_project) { create(:project, name: 'another_target_project') }
    let(:another_target_package) { create(:package, name: 'another_target_package', project: another_target_project) }
    let(:source_project) { create(:project, :as_submission_source, name: 'source_project') }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }
    let(:devel_project) { create(:project, name: 'devel_project', maintainer: maintainer) }
    let(:devel_package) { create(:package, name: 'devel_package', project: devel_project) }
    let(:submit_request) do
      create(:bs_request_with_submit_action,
             target_package: devel_package,
             source_package: source_package)
    end
    let(:actions) { submit_request.bs_request_actions }
    let(:action) { actions.first }
    let(:package_maintainers) do
      distinct_bs_request_actions = actions.select(:target_project, :target_package).distinct
      distinct_bs_request_actions.flat_map do |action|
        Package.find_by_project_and_name(action.target_project, action.target_package).try(:maintainers)
      end.compact.uniq
    end

    before do
      target_package.update(develpackage: devel_package)
      another_target_package.update(develpackage: devel_package)
      User.session = maintainer
      render_inline(described_class.new(bs_request: submit_request, action: action, is_target_maintainer: true, package_maintainers: package_maintainers, show_project_maintainer_hint: true))
    end

    it 'shows the Accept button as a dropdown' do
      expect(rendered_content).to have_button(id: 'decision-buttons-group')
    end

    it 'shows an option to accept the request only' do
      expect(rendered_content).to have_css('input[value="Accept request"]')
    end

    it 'shows an option to accept and forward the request' do
      expect(rendered_content).to have_css("input[value='Accept and forward submit request to #{target_project}/#{target_package} and #{another_target_project}/#{another_target_package}']")
    end

    it 'shows an option to accept, make the creator a maintainer and forward the request' do
      expect(rendered_content).to have_css("input[value='Accept making #{submit_request.creator} maintainer of " \
                                           "#{devel_project}/#{devel_package} and forwarding submit request to " \
                                           "#{target_project}/#{target_package} and #{another_target_project}/#{another_target_package}']")
    end
  end
end
