require 'rails_helper'

RSpec.describe WorkflowRunFilterLinkComponent, type: :component do
  let(:workflow_token) { build_stubbed(:workflow_token, id: 1) }

  describe 'status filter links' do
    before do
      render_inline(described_class.new(token: workflow_token, text: 'Succeeded', amount: 1,
                                        filter_item: filter_item, selected_filter: selected_filter))
    end

    context 'when the selected filter matches the filter item' do
      let(:filter_item) { { status: 'success' } }
      let(:selected_filter) { { status: 'success' } }
      let(:link_selector) { 'a.active[href="/my/tokens/1/workflow_runs?status=success"]' }

      it 'displays link with active class and a light badge' do
        expect(rendered_content).to have_css("#{link_selector} span.badge.text-bg-light")
      end
    end

    context 'when the selected filter does not match the filter item' do
      let(:filter_item) { { status: 'success' } }
      let(:selected_filter) { { status: 'fail' } }
      let(:link_selector) { 'a[href="/my/tokens/1/workflow_runs?status=success"]' }

      it 'displays link without active class and a primary badge' do
        expect(rendered_content).to have_css("#{link_selector} span.badge.text-bg-primary")
      end
    end
  end

  describe 'event type filter links' do
    before do
      render_inline(described_class.new(token: workflow_token, text: 'Pull Request', amount: 1,
                                        filter_item: filter_item, selected_filter: selected_filter))
    end

    context 'when the selected filter matches the filter item' do
      let(:filter_item) { { generic_event_type: 'pull_request' } }
      let(:selected_filter) { { generic_event_type: 'pull_request' } }
      let(:link_selector) { 'a.active[href="/my/tokens/1/workflow_runs?generic_event_type=pull_request"]' }

      it 'displays link with active class and a light badge' do
        expect(rendered_content).to have_css("#{link_selector} span.badge.text-bg-light")
      end
    end

    context 'when the selected filter does not match the filter item' do
      let(:filter_item) { { generic_event_type: 'pull_request' } }
      let(:selected_filter) { { generic_event_type: 'push' } }
      let(:link_selector) { 'a[href="/my/tokens/1/workflow_runs?generic_event_type=pull_request"]' }

      it 'displays link without active class and a primary badge' do
        expect(rendered_content).to have_css("#{link_selector} span.badge.text-bg-primary")
      end
    end
  end

  context 'when the amount of workflow runs for the filter is zero' do
    let(:link_selector) { 'a.active[href="/my/tokens/1/workflow_runs?status=success"]' }

    before do
      render_inline(described_class.new(token: workflow_token, text: 'Succeeded', amount: 0,
                                        filter_item: { status: 'success' }, selected_filter: { status: 'success' }))
    end

    it 'does not show a badge for the displayed filter link' do
      expect(rendered_content).not_to have_css("#{link_selector} span.badge")
    end
  end
end
