RSpec.describe WorkflowArtifactsPerStepComponent, type: :component do
  let(:workflow_run) { create(:workflow_run) }

  let(:record) do
    build(:workflow_artifacts_per_step_rebuild_package,
          workflow_run: workflow_run,
          source_project_name: 'home:foo',
          source_package_name: 'bar')
  end

  context 'when artifacts is a Hash (correctly serialized record)' do
    before do
      allow(record).to receive(:artifacts).and_return(
        { 'project' => 'home:foo', 'package' => 'bar' }
      )
      render_inline(described_class.new(artifacts_per_step: record))
    end

    it { expect(rendered_content).to have_text('home:foo') }
    it { expect(rendered_content).to have_text('bar') }
  end

  context 'when artifacts is a String (legacy double-encoded record)' do
    before do
      allow(record).to receive(:artifacts).and_return(
        { project: 'home:foo', package: 'bar' }.to_json
      )
      render_inline(described_class.new(artifacts_per_step: record))
    end

    it { expect(rendered_content).to have_text('home:foo') }
    it { expect(rendered_content).to have_text('bar') }
  end
end
