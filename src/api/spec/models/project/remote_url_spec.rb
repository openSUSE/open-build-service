require 'webmock/rspec'

RSpec.describe Project::RemoteURL do
  describe '.load' do
    subject { described_class.load(remote_project, '/distributions.xml') }

    let(:remote_project) { build_stubbed(:remote_project, remoteurl: 'http://example.com') }

    before do
      allow(Airbrake).to receive(:notify)
    end

    context 'when the remote server responds successfully' do
      before do
        stub_request(:get, 'http://example.com/distributions.xml')
          .to_return(status: 200, body: '<distributions />')
      end

      it { is_expected.to eq('<distributions />') }

      it 'does not notify Airbrake' do
        subject
        expect(Airbrake).not_to have_received(:notify)
      end
    end

    context 'when a remote OBS backend answers with 400 unknown request' do
      before do
        stub_request(:get, 'http://example.com/distributions.xml')
          .to_return(status: [400, 'unknown request: GET:/distributions.xml'])
      end

      it { is_expected.to be_nil }

      it 'does not notify Airbrake' do
        subject
        expect(Airbrake).not_to have_received(:notify)
      end
    end

    context 'when a remote OBS backend answers with 400 unknown request without a colon' do
      before do
        stub_request(:get, 'http://example.com/distributions.xml')
          .to_return(status: [400, 'unknown request  GET /distributions.xml'])
      end

      it { is_expected.to be_nil }

      it 'does not notify Airbrake' do
        subject
        expect(Airbrake).not_to have_received(:notify)
      end
    end

    context 'when the remote server responds with another 400 error' do
      before do
        stub_request(:get, 'http://example.com/distributions.xml')
          .to_return(status: [400, 'Bad Request'])
      end

      it { is_expected.to be_nil }

      it 'notifies Airbrake' do
        subject
        expect(Airbrake).to have_received(:notify).with(OpenURI::HTTPError)
      end
    end

    context 'when the remote server responds with another HTTP error' do
      before do
        stub_request(:get, 'http://example.com/distributions.xml')
          .to_return(status: [500, 'Internal Server Error'])
      end

      it { is_expected.to be_nil }

      it 'notifies Airbrake' do
        subject
        expect(Airbrake).to have_received(:notify).with(OpenURI::HTTPError)
      end
    end

    context 'when the remote server returns 404 Not Found' do
      before do
        stub_request(:get, 'http://example.com/distributions.xml')
          .to_return(status: [404, 'Not Found'])
      end

      it { is_expected.to be_nil }

      it 'does not notify Airbrake' do
        subject
        expect(Airbrake).not_to have_received(:notify)
      end
    end
  end
end
