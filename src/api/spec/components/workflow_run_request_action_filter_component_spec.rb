require 'rails_helper'

RSpec.describe WorkflowRunRequestActionFilterComponent, type: :component do
  let(:workflow_token) { create(:workflow_token) }

  it 'shows correct filter options' do
    render_inline(described_class.new(token_id: workflow_token.id))
    filters = ['all'] + SCMWebhook::ALLOWED_PULL_REQUEST_ACTIONS + SCMWebhook::ALLOWED_MERGE_REQUEST_ACTIONS

    filters.each do |filter|
      expect(rendered_content).to have_text(filter)
    end
  end
end
