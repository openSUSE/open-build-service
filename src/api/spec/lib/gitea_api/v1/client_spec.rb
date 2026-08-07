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

      {
        400 => GiteaAPI::V1::Client::BadRequestError,
        401 => GiteaAPI::V1::Client::UnauthorizedError,
        403 => GiteaAPI::V1::Client::ForbiddenError,
        404 => GiteaAPI::V1::Client::NotFoundError,
        429 => GiteaAPI::V1::Client::TooManyRequestsError,
        500 => GiteaAPI::V1::Client::InternalServerError,
        502 => GiteaAPI::V1::Client::BadGatewayError,
        503 => GiteaAPI::V1::Client::ServiceUnavailableError,
        # Server errors without a dedicated class
        504 => GiteaAPI::V1::Client::ServerError,
        599 => GiteaAPI::V1::Client::ServerError,
        # Any other status falls back to the generic error
        418 => GiteaAPI::V1::Client::ApiError,
        451 => GiteaAPI::V1::Client::ApiError
      }.each do |response_status, error_class|
        context "when the response status is #{response_status}" do
          let(:status) { response_status }

          it "sends a post request and raises #{error_class}" do
            expect { subject }.to raise_error(error_class, "HTTP Code: #{response_status}, response: upppsss something went wrong")
          end
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

        it 'raises a ConnectionError' do
          expect { subject }.to raise_error(GiteaAPI::V1::Client::ConnectionError, 'Failed to report back to Gitea: connection refused')
        end
      end

      context 'because the request timed out' do
        let(:faraday_error) { Faraday::TimeoutError.new('execution expired') }

        it 'raises a ConnectionError' do
          expect { subject }.to raise_error(GiteaAPI::V1::Client::ConnectionError, 'Failed to report back to Gitea: execution expired')
        end
      end

      context 'because the SSL handshake failed' do
        let(:faraday_error) { Faraday::SSLError.new('certificate verify failed') }

        it 'raises an SSLError instead of a ConnectionError' do
          expect { subject }.to raise_error(GiteaAPI::V1::Client::SSLError, 'Failed to report back to Gitea: certificate verify failed')
        end
      end
    end
  end
end
