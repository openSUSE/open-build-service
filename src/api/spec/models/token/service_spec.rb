RSpec.describe Token::Service do
  subject { token.call(package: 'bar') }

  let(:user) { create(:user, login: 'foo') }
  let(:token) { create(:service_token, executor: user) }

  describe '#call' do
    context 'successful triggered' do
      before do
        allow(Backend::Api::Sources::Package).to receive(:trigger_services).and_return(true)
      end

      it 'records the current date and time in the triggered_at column' do
        expect { subject }.to change(token, :triggered_at)
      end
    end

    context 'triggered without success' do
      before do
        allow(Backend::Api::Sources::Package).to receive(:trigger_services).and_raise(Backend::Error, 'something went wrong')
      end

      it 'records the current date and time in the triggered_at column' do
        expect { subject }.to raise_error(Backend::Error).and(change(token, :triggered_at))
      end
    end
  end
end
