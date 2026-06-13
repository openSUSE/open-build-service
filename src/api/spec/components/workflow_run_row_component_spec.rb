RSpec.describe WorkflowRunRowComponent, type: :component do
  before do
    render_inline(described_class.new(workflow_run: workflow_run, token_id: workflow_run.token.id))
  end

  context 'when the push event contains a head commit URL' do
    let(:workflow_run) { create(:workflow_run, :push) }

    it do
      expect(rendered_content).to have_css("a[href='#{workflow_run.event_source_url}'][title='Go to Event Source #{workflow_run.formatted_event_source_name}']")
    end

    it { expect(rendered_content).to have_link(href: "?event_source=#{workflow_run.event_source_name}") }
  end

  context 'when the push event does not contain a head commit URL' do
    let(:workflow_run) { create(:workflow_run, :push, request_payload: request_payload_without_head_commit) }
    let(:request_payload_without_head_commit) do
      payload = JSON.parse(File.read('spec/fixtures/files/request_payload_github_push.json'))
      payload['head_commit'] = nil
      payload.to_json
    end

    it { expect(workflow_run.event_source_url).to be_nil }
    it { expect(rendered_content).to have_text(workflow_run.formatted_event_source_name) }
    it { expect(rendered_content).to have_no_css("a[title='Go to Event Source #{workflow_run.formatted_event_source_name}']") }
    it { expect(rendered_content).to have_link(href: "?event_source=#{workflow_run.event_source_name}") }
  end
end
