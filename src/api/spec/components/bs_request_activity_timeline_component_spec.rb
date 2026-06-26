RSpec.describe BsRequestActivityTimelineComponent, type: :component do
  let(:bs_request) { create(:bs_request_with_submit_action) }
  let!(:history_element) { create(:history_element_request_accepted, op_object_id: bs_request.id) }
  let!(:comment) { travel_to(1.day.ago) { create(:comment_request, commentable: bs_request) } }

  it 'shows the comment first, as it is an older timeline item' do
    expect(render_inline(described_class.new(bs_request: bs_request, history_elements: [history_element]))).to have_css('.timeline-item:first-child', text: comment.user.login)
    expect(render_inline(described_class.new(bs_request: bs_request, history_elements: [history_element]))).to have_css('.timeline-item:first-child', text: '1 day ago')
  end

  it 'shows the history element in the second position, as it is more recent' do
    expect(render_inline(described_class.new(bs_request: bs_request, history_elements: [history_element]))).to have_css('.timeline-item:last-child', text: 'accepted request')
  end
end
