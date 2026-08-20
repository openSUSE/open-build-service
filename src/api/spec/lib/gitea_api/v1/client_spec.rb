RSpec.describe GiteaAPI::V1::Client do
  let(:client) { described_class.new(api_endpoint: 'https://gitea.opensuse.org', token: '12345') }
  let(:faraday) { instance_double(Faraday::Connection) }

  describe '#create_commit_status' do
    context 'when it is successful' do
      let(:url) { 'repos/krauselukas/hello_world/statuses/abc123cdf' }

      before do
        allow(Faraday::Connection).to receive(:new).and_return(faraday)
        allow(faraday).to receive(:post).and_return(Faraday::Response)
        allow(Faraday::Response).to receive_messages(status: 200, body: true)

        client.create_commit_status(owner: 'krauselukas', repo: 'hello_world', sha: 'abc123cdf', state: 'succeeded')
      end

      it 'sends a post request to the correct api endpoint' do
        expect(faraday).to have_received(:post).with(url, { context: nil, description: nil, state: 'succeeded', target_url: nil })
      end
    end

    context 'when something goes wrong' do
      subject { client.create_commit_status(owner: 'krauselukas', repo: 'hello_world', sha: 'abc123cdf', state: 'succeeded') }

      before do
        allow(Faraday::Connection).to receive(:new).and_return(faraday)
        allow(faraday).to receive(:post).and_return(Faraday::Response)
        allow(Faraday::Response).to receive_messages(status: status, body: { 'message' => 'upppsss something went wrong' })
      end

      context 'when the response status is 400' do
        let(:status) { 400 }

        it "sends a post request and raises #{GiteaAPI::V1::Client::BadRequestError}" do
          expect { subject }.to raise_error(GiteaAPI::V1::Client::BadRequestError, 'HTTP Code: 400, response: upppsss something went wrong')
        end
      end
    end

    context 'when the request never reaches Gitea' do
      subject { client.create_commit_status(owner: 'krauselukas', repo: 'hello_world', sha: 'abc123cdf', state: 'succeeded') }

      before do
        allow(Faraday::Connection).to receive(:new).and_return(faraday)
        allow(faraday).to receive(:post).and_raise(faraday_error)
      end

      context 'because the connection failed' do
        let(:faraday_error) { Faraday::ConnectionFailed.new('connection refused') }

        it 'raises a ConnectionFailedError' do
          expect { subject }.to raise_error(GiteaAPI::V1::Client::ConnectionFailedError, 'Failed to report back to Gitea: connection refused')
        end
      end

      context 'because the request timed out' do
        let(:faraday_error) { Faraday::TimeoutError.new('execution expired') }

        it 'raises a TimeoutError instead of a ConnectionFailedError' do
          expect { subject }.to raise_error(GiteaAPI::V1::Client::TimeoutError, 'Failed to report back to Gitea: execution expired')
        end
      end

      context 'because the SSL handshake failed' do
        let(:faraday_error) { Faraday::SSLError.new('certificate verify failed') }

        it 'raises an SSLError' do
          expect { subject }.to raise_error(GiteaAPI::V1::Client::SSLError, 'Failed to report back to Gitea: certificate verify failed')
        end

        # A failed handshake is a permanent configuration problem, so it must stay outside the
        # ConnectionError family, which ReportToSCMJob retries.
        it 'is not part of the ConnectionError family' do
          expect(GiteaAPI::V1::Client::SSLError.ancestors).not_to include(GiteaAPI::V1::Client::ConnectionError)
        end
      end
    end
  end
end
