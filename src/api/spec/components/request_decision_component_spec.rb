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
    it 'shows the Accept button as a dropdown'
    it 'shows an option to accept the request only'
    it 'shows an option to accept and forward the request'
  end

  context 'when we can forward the request and make the creator a maintainer' do
    it 'shows the Accept button as a dropdown'
    it 'shows an option to accept the request only'
    it 'shows an option to accept and forward the request'
    it 'shows an option to accept, make the creator a maintainer and forward the request'
  end
end
