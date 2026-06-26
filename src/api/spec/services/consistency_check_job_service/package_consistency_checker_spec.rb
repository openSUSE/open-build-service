RSpec.describe ConsistencyCheckJobService::PackageConsistencyChecker, :vcr do
  let(:project) { create(:project, name: 'super_bacana') }
  let(:package_consistency_checker) { described_class.new(project) }

  describe '#call' do
    context 'everything goes well' do
      it { expect { package_consistency_checker.call }.not_to raise_error }
    end
  end
end
