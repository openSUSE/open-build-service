require 'rails_helper'

RSpec.describe WorkflowRunDetailComponent, type: :component do
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

  before do
    render_inline(described_class.new(workflow_run: workflow_run))
  end

  context 'when the payload cannot be parsed' do
    let(:request_payload) { 'Unparseable payload' }

    it 'shows nothing on the payload tab' do
      expect(rendered_content).to have_text('Unparseable payload')
    end
  end

  context 'in Workflow Configuration tab' do
    context 'when the configuration information was not stored' do
      it { expect(rendered_content).to have_text('This information is not available.') }
    end

    context 'when the configuration path was stored' do
      let(:workflow_run) { create(:workflow_run, :with_configuration_path, token: workflow_token) }

      it { expect(rendered_content).to have_text('Workflow Configuration File Path') }
      it { expect(rendered_content).to have_text('.obs/workflows.yml') }
    end

    context 'when the configuration URL was stored' do
      let(:workflow_run) { create(:workflow_run, :with_configuration_url, token: workflow_token) }

      it { expect(rendered_content).to have_text('Workflow Configuration File URL') }
      it { expect(rendered_content).to have_text('http://example.com/workflows.yml') }
    end
  end
end
