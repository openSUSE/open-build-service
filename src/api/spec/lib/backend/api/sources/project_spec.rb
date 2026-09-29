RSpec.describe Backend::Api::Sources::Project do
  let(:project_name) { 'home:tom' }

  describe '.pubkeys' do
    it 'calls _pubkeys endpoint' do
      allow(described_class).to receive(:http_get).and_return('ok')

      described_class.pubkeys(project_name)

      expect(described_class).to have_received(:http_get).with(['/source/:project/_pubkeys', project_name])
    end
  end

  describe '.preparekey' do
    let(:request_params) { { user: 'tom', comment: 'prepare', keyalgo: 'rsa@4096', days: 800 } }
    let(:expected_post_args) do
      [
        ['/source/:project', project_name],
        { defaults: { cmd: :preparekey }, params: request_params, accepted: %i[user comment keyalgo days] }
      ]
    end

    it 'posts preparekey with accepted params' do
      allow(described_class).to receive(:http_post).and_return('ok')
      described_class.preparekey(project_name, request_params)
      expect(described_class).to have_received(:http_post).with(*expected_post_args)
    end
  end

  describe '.activatekey' do
    let(:request_params) { { user: 'tom', comment: 'activate' } }
    let(:expected_post_args) do
      [
        ['/source/:project', project_name],
        { defaults: { cmd: :activatekey }, params: request_params, accepted: %i[user comment] }
      ]
    end

    it 'posts activatekey with accepted params' do
      allow(described_class).to receive(:http_post).and_return('ok')
      described_class.activatekey(project_name, request_params)
      expect(described_class).to have_received(:http_post).with(*expected_post_args)
    end
  end
end
