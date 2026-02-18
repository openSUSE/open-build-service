RSpec.describe Backend::Api::Sources::Project do
  describe '.pubkeys' do
    it 'calls _pubkeys endpoint' do
      allow(described_class).to receive(:http_get).and_return('ok')

      described_class.pubkeys('home:tom')

      expect(described_class).to have_received(:http_get).with(['/source/:project/_pubkeys', 'home:tom'])
    end
  end

  describe '.preparekey' do
    it 'posts preparekey with accepted params' do
      allow(described_class).to receive(:http_post).and_return('ok')

      described_class.preparekey('home:tom', user: 'tom', comment: 'prepare', keyalgo: 'rsa@4096', days: 800)

      expect(described_class).to have_received(:http_post).with(
        ['/source/:project', 'home:tom'],
        defaults: { cmd: :preparekey },
        params: { user: 'tom', comment: 'prepare', keyalgo: 'rsa@4096', days: 800 },
        accepted: %i[user comment keyalgo days]
      )
    end
  end

  describe '.activatekey' do
    it 'posts activatekey with accepted params' do
      allow(described_class).to receive(:http_post).and_return('ok')

      described_class.activatekey('home:tom', user: 'tom', comment: 'activate')

      expect(described_class).to have_received(:http_post).with(
        ['/source/:project', 'home:tom'],
        defaults: { cmd: :activatekey },
        params: { user: 'tom', comment: 'activate' },
        accepted: %i[user comment]
      )
    end
  end
end
