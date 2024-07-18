RSpec.describe WorkflowRunDetailComponent, type: :component do
  context 'with a workflow run with configuration data path' do
    let(:workflow_run_with_path) { create(:workflow_run) }

    before do
      render_inline(described_class.new(workflow_run: workflow_run_with_path))
    end

    it { expect(rendered_content).to have_text('Workflow Configuration File Path') }
    it { expect(rendered_content).to have_text('Workflow Configuration') }
  end

  context 'with a workflow run with configuration data URL' do
    let(:workflow_run_with_url) { create(:workflow_run, :with_url) }

    before do
      render_inline(described_class.new(workflow_run: workflow_run_with_url))
    end

    it { expect(rendered_content).to have_text('Workflow Configuration File URL') }
    it { expect(rendered_content).to have_text('Workflow Configuration') }
  end

  context 'with a workflow run without configuration data' do
    let(:workflow_run_without_data) { create(:workflow_run, :without_configuration_data) }

    before do
      render_inline(described_class.new(workflow_run: workflow_run_without_data))
    end

    it { expect(rendered_content).to have_no_text('Workflow Configuration File Path') }
    it { expect(rendered_content).to have_no_text('Workflow Configuration File URL') }
    it { expect(rendered_content).to have_text('This information is not available.') }
  end
end
