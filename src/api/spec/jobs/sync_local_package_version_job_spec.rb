RSpec.describe SyncLocalPackageVersionJob do
  describe '#perform' do
    context 'when the project no longer exists' do
      it 'skips syncing local package versions' do
        expect { described_class.perform_now('deleted-project') }.not_to raise_error
      end
    end
  end
end
