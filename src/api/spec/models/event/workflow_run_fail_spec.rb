RSpec.describe Event::WorkflowRunFail do
  describe '#token_executor' do
    subject { event.token_executors }

    let(:token) { create(:workflow_token) }
    let(:event) { Event::WorkflowRunFail.create(token_id: token.id) }

    it { expect(subject).to contain_exactly(token.executor) }

    context 'when the token does not exist' do
      before do
        event
        token.destroy
      end

      it { expect(subject).to be_empty }
    end
  end
end
