require 'rails_helper'

RSpec.describe WorkflowArtifactsPerStepComponent, type: :component do
  let(:workflow_token) { create(:workflow_token) }
  let(:request_headers) do
    <<~END_OF_HEADERS
      HTTP_X_GITHUB_EVENT: pull_request
    END_OF_HEADERS
  end
  let(:request_payload) do
    <<-END_OF_PAYLOAD
    {
      "foo": "bar"
    }
    END_OF_PAYLOAD
  end
  let(:workflow_run) do
    create(:workflow_run,
           token: workflow_token,
           request_headers: request_headers,
           request_payload: request_payload)
  end
  let(:scm_webhook) do
    SCMWebhook.new(payload: extractor_payload)
  end
  let(:artifacts_per_step) do
    WorkflowArtifactsPerStep.new(workflow_run: workflow_run, artifacts: artifacts, step: step_name)
  end

  before do
    render_inline(described_class.new(artifacts_per_step: artifacts_per_step))
  end

  context 'when artifacts JSON can not be parsed' do
    let(:step_name) { 'Workflow::Step::BranchPackageStep' }
    let(:artifacts) { nil }

    it { expect(rendered_content).to have_text("Could not display artifacts for #{step_name.split('::').last.titleize}") }

    it 'does not show any link' do
      expect(rendered_content).not_to have_link
    end
  end

  context 'when artifacts data is not valid' do
    let(:step_name) { 'Workflow::Step::BranchPackageStep' }
    let(:artifacts) do
      {
        foo: 'bar'
      }.to_json
    end

    it { expect(rendered_content).to have_text("Could not display artifacts for #{step_name.split('::').last.titleize}") }

    it 'does not show any link' do
      expect(rendered_content).not_to have_link
    end
  end

  context 'step is a branch package step' do
    let(:step_name) { 'Workflow::Step::BranchPackageStep' }
    let(:artifacts) do
      {
        source_project: 'devel:languages:ruby:extensions',
        source_package: 'ruby2.5',
        target_project: 'home:Admin:branches:devel:languages:ruby:extensions',
        target_package: 'ruby2.5'
      }.to_json
    end

    it { expect(rendered_content).to have_text('Branched package from') }

    it 'shows a link to the source package' do
      expect(rendered_content).to have_link('devel:languages:ruby:extensions/ruby2.5',
                                            href: '/package/show/devel:languages:ruby:extensions/ruby2.5')
    end

    it 'shows a link to the target package' do
      expect(rendered_content).to have_link('home:Admin:branches:devel:languages:ruby:extensions/ruby2.5',
                                            href: '/package/show/home:Admin:branches:devel:languages:ruby:extensions/ruby2.5')
    end
  end

  context 'step is a link package step' do
    let(:artifacts) do
      {
        source_project: 'devel:languages:ruby:extensions',
        source_package: 'ruby2.5',
        target_project: 'home:Admin:branches:devel:languages:ruby:extensions',
        target_package: 'ruby2.5'
      }.to_json
    end
    let(:step_name) { 'Workflow::Step::LinkPackageStep' }

    it { expect(rendered_content).to have_text('Linked package from') }

    it 'shows a link to the source package' do
      expect(rendered_content).to have_link('devel:languages:ruby:extensions/ruby2.5',
                                            href: '/package/show/devel:languages:ruby:extensions/ruby2.5')
    end

    it 'shows a link to the target package' do
      expect(rendered_content).to have_link('home:Admin:branches:devel:languages:ruby:extensions/ruby2.5',
                                            href: '/package/show/home:Admin:branches:devel:languages:ruby:extensions/ruby2.5')
    end
  end

  context 'step is a rebuild package step' do
    let(:artifacts) do
      {
        project: 'devel:languages:ruby:extensions',
        package: 'ruby2.5'
      }.to_json
    end
    let(:step_name) { 'Workflow::Step::RebuildPackage' }

    it { expect(rendered_content).to have_text('Rebuilt package') }

    it 'shows a link to the rebuilt package' do
      expect(rendered_content).to have_link('devel:languages:ruby:extensions/ruby2.5',
                                            href: '/package/show/devel:languages:ruby:extensions/ruby2.5')
    end
  end

  context 'step is a trigger services step' do
    let(:artifacts) do
      {
        project: 'devel:languages:ruby:extensions',
        package: 'ruby2.5'
      }.to_json
    end
    let(:step_name) { 'Workflow::Step::TriggerServices' }

    it { expect(rendered_content).to have_text('Triggered services on package') }

    it 'shows a link to the package where we triggered the services' do
      expect(rendered_content).to have_link('devel:languages:ruby:extensions/ruby2.5',
                                            href: '/package/show/devel:languages:ruby:extensions/ruby2.5')
    end
  end

  context 'step is a configure repositories step' do
    let(:artifacts) do
      {
        project: 'devel:languages:ruby:extensions',
        repositories: []
      }.to_json
    end

    let(:step_name) { 'Workflow::Step::ConfigureRepositories' }

    it { expect(rendered_content).to have_text('Configured repositories') }

    it 'shows a link to the configured repositories of a project' do
      expect(rendered_content).to have_link('repositories',
                                            href: '/project/repositories/devel:languages:ruby:extensions')
    end
  end
end
