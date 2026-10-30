RSpec.describe BsRequestSummaryDescriptionComponent, type: :component do
  let(:bs_request) do
    build(:bs_request, bs_request_actions: Array.new(actions_count) do |i|
      build(:bs_request_action_submit, source_project: 'home:foo', source_package: "pkg#{i}",
                                       target_project: 'openSUSE:Factory', target_package: "pkg#{i}")
    end)
  end

  def popover_lines(text)
    popover = page.find('span[data-request-actions-popover]', text: text, match: :first)
    Nokogiri::HTML.fragment(popover['data-bs-content']).css('li').map(&:text)
  end

  before { render_inline(described_class.new(bs_request:)) }

  context 'with a few actions' do
    let(:actions_count) { 5 }

    it 'lists the source packages one per line in a popover' do
      lines = popover_lines('3 others')

      expect(lines.size).to eq(5)
      expect(lines.first).to eq('home:foo / pkg0')
    end
  end

  context 'with more actions than the popover shows' do
    let(:actions_count) { 30 }

    it 'cuts the list and points to the request' do
      lines = popover_lines('28 others')

      expect(lines.size).to eq(26)
      expect(lines.last).to eq('and 5 more, see the request')
    end
  end
end
