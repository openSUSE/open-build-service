require 'rails_helper'

RSpec.describe WorkflowRunFilterComponent, type: :component do
  let(:token) { create(:workflow_token) }
  let(:stub_finder) do
    instance_double('WorkflowRunsFinder',
                    succeeded: [:workflow_run],
                    running: [:workflow_run, :workflow_run],
                    failed: [:workflow_run, :workflow_run, :workflow_run],
                    group_by_event_type: { pull_request: [:workflow_run] })
  end
  let(:selected_filter) { {} }

  before do
    render_inline(described_class.new(token: token, selected_filter: selected_filter, finder: stub_finder))
  end

  it 'renders a link to receive all workflow runs' do
    expect(rendered_component).to have_css('a.active', text: 'All')
  end

  context 'status filter links' do
    it 'renders the succeeded filter' do
      expect(rendered_component).to have_css('a', text: 'Succeeded')
    end

    it 'renders the failed filter' do
      expect(rendered_component).to have_css('a', text: 'Failed')
    end

    it 'renders the running filter' do
      expect(rendered_component).to have_css('a', text: 'Running')
    end
  end

  context 'event type filter links' do
    it 'renders the push event filters' do
      expect(rendered_component).to have_css('a', text: 'Push')
      expect(rendered_component).to have_css('a', text: 'Push Hook')
    end

    it 'renders the pull request event filters' do
      expect(rendered_component).to have_css('a', text: 'Pull Requests')
      expect(rendered_component).to have_css('a', text: 'Merge Request Hook')
    end
  end
end
