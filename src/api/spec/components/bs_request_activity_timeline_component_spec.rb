require 'rails_helper'

RSpec.describe BsRequestActivityTimelineComponent, type: :component do
  let(:bs_request) { create(:bs_request_with_submit_action) }
  let!(:history_element) { create(:history_element_request_accepted, op_object_id: bs_request.id) }
  let!(:comment) { travel_to(1.day.ago) { create(:comment_request, commentable: bs_request) } }

  it 'shows the comment first, as it is an older timeline item' do
    expect(render_inline(described_class.new(bs_request: bs_request))).to have_selector('.timeline-item:first-child', text: 'wrote')
    expect(render_inline(described_class.new(bs_request: bs_request))).to have_selector('.timeline-item:first-child', text: '1 day ago')
  end

  it 'shows the history element in the second position, as it is more recent' do
    expect(render_inline(described_class.new(bs_request: bs_request))).to have_selector('.timeline-item:last-child', text: 'accepted request')
  end
end
