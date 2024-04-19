RSpec.describe CannedResponsesDropdownComponent, type: :component do
  let(:moderator) { create(:moderator) }
  let!(:generic_canned_response) { create(:canned_response, title: 'LGTM', user: moderator) }
  let!(:cleared_canned_response) { create(:cleared_canned_response, title: 'No spam', user: moderator) }
  let!(:favored_canned_response) { create(:favored_canned_response, title: 'I agree', user: moderator) }

  context 'with generic responses only' do
    before do
      render_inline(described_class.new(CannedResponse.where(decision_type: nil)))
    end

    it { expect(rendered_content).to have_text('Generic') }
    it { expect(rendered_content).to have_text('LGTM') }
  end

  context 'with cleared decision responses only' do
    before do
      render_inline(described_class.new(CannedResponse.where(decision_type: 'cleared')))
    end

    it { expect(rendered_content).to have_no_text('Generic') }
    it { expect(rendered_content).to have_no_text('Favored') }
    it { expect(rendered_content).to have_text('Cleared') }
    it { expect(rendered_content).to have_text('No spam') }
  end

  context 'with favored decision responses only' do
    before do
      render_inline(described_class.new(CannedResponse.where(decision_type: 'favored')))
    end

    it { expect(rendered_content).to have_no_text('Generic') }
    it { expect(rendered_content).to have_no_text('Cleared') }
    it { expect(rendered_content).to have_text('Favored') }
    it { expect(rendered_content).to have_text('I agree') }
  end

  context 'with the three types of responses' do
    before do
      render_inline(described_class.new(CannedResponse.all))
    end

    it { expect(rendered_content).to have_text('Generic') }
    it { expect(rendered_content).to have_text('Cleared') }
    it { expect(rendered_content).to have_text('Favored') }
    it { expect(rendered_content).to have_text('LGTM') }
    it { expect(rendered_content).to have_text('No spam') }
    it { expect(rendered_content).to have_text('I agree') }
  end
end
