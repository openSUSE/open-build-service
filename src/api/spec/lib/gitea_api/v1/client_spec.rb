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
      before do
        allow(Faraday::Connection).to receive(:new).and_return(faraday)
        allow(faraday).to receive(:post).and_return(Faraday::Response)
        allow(Faraday::Response).to receive_messages(status: 400, body: { 'message' => 'upppsss something went wrong' })
      end

      it 'sends a post request and returns the correct exception class' do
        expect { client.create_commit_status(owner: 'krauselukas', repo: 'hello_world', sha: 'abc123cdf', state: 'succeeded') }.to raise_error(GiteaAPI::V1::Client::BadRequestError)
      end
    end
  end
end
