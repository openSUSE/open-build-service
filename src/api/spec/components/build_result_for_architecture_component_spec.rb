require 'rails_helper'

RSpec.describe BuildResultForArchitectureComponent, type: :component do
  let(:project) { 'fake_project' }
  let(:package) { 'fake_package' }

  before do
    render_inline(described_class.new(result, project, package))
  end

  context 'with succeeded result' do
    let(:result) do
      LocalBuildResult.new(
        repository: '15.4',
        architecture: 'x86_64',
        code: 'succeeded',
        state: 'blocked',
        is_repository_in_db: 'true'
      )
    end

    it { expect(rendered_content).to have_selector('.build-result', class: 'border-success') }
    it { expect(rendered_content).to have_selector('.build-status i', class: 'fa-check text-success') }
    it { expect(rendered_content).to have_selector('.build-status span', text: 'succeeded') }
    it { expect(rendered_content).to have_selector('.repository-status i', class: 'fa-lock') }
    it { expect(rendered_content).to have_selector('.repository-status span', text: 'blocked') }
    it { expect(rendered_content).not_to have_selector("div[data-bs-content*='Details']") }
  end

  context 'with excluded but visible result' do
    let(:result) do
      LocalBuildResult.new(
        repository: '15.4',
        architecture: 'x86_64',
        code: 'excluded',
        state: 'published',
        is_repository_in_db: 'true',
        details: 'fake details'
      )
    end

    it { expect(rendered_content).to have_selector('.build-result', class: 'border-gray-300') }
    it { expect(rendered_content).to have_selector('.build-status i', class: 'fa-xmark text-gray-500') }
    it { expect(rendered_content).to have_selector('.build-status span', text: 'excluded') }
    it { expect(rendered_content).to have_selector('.repository-status i', class: 'fa-truck') }
    it { expect(rendered_content).to have_selector('.repository-status span', text: 'published') }
    it { expect(rendered_content).to have_selector("div[data-bs-content*='fake details']") }
  end
end
