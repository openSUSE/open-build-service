RSpec.describe WriteAndPreviewComponent, type: :component do
  let(:form) { double('FormBuilder', text_area: 'text area') }

  describe '#request_canned_responses' do
    context 'when bs_request responds to canned_responses' do
      let(:canned_responses) { double('CannedResponses') }
      let(:bs_request) { double('BsRequest', canned_responses: canned_responses) }
      let(:component) { described_class.new(form: form, preview_message_url: '/preview', message_body_param: 'body', bs_request: bs_request) }

      it 'returns the bs_request canned responses' do
        expect(canned_responses).to receive(:where).with(decision_type: nil).and_return('filtered_responses')
        expect(component.send(:request_canned_responses)).to eq('filtered_responses')
      end
    end

    context 'when bs_request is nil' do
      let(:component) { described_class.new(form: form, preview_message_url: '/preview', message_body_param: 'body', bs_request: nil) }

      it 'returns CannedResponse.none' do
        expect(component.send(:request_canned_responses)).to eq(CannedResponse.none)
      end
    end
  end
end
