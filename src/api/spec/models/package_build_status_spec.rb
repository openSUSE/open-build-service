RSpec.describe PackageBuildStatus, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'foo') }
  let!(:package) { create(:package, name: 'foo', project: user.home_project, commit_user: user) }

  describe '.new' do
    subject { described_class.new(package) }

    it { expect { subject }.not_to raise_error }
  end

  describe '#gather_md5sums' do
    let(:package_build_status) { described_class.new(package) }
    let(:revision) { 'd3b07384d113edec49eaa6238ad5ff00' }

    before do
      package_build_status.instance_variable_set(:@srcmd5, revision)
    end

    it { expect { package_build_status.gather_md5sums }.not_to raise_error }
    it { expect(package_build_status.gather_md5sums).to eq(revision) }
  end

  describe '#current_dir' do
    subject { described_class.new(package).current_dir }

    it { expect { subject }.not_to raise_error }
    it { expect(subject).to be_a(Hash) }
  end

  describe 'gather_target_packages' do
    subject { described_class.new(package).gather_target_packages(repository_hash) }

    let!(:repository_hash) do
      {
        user.home_project.name => 'foo'
      }
    end

    it { expect { subject }.not_to raise_error }
    it { expect(subject).to be_a(Hash) }
  end

  describe '#check_everbuilt' do
    subject { package_build_status.check_everbuilt(repo_hash, arch_name) }

    let(:arch_name) { 'i386' }
    let(:repo_hash) { { 'name' => 'foo' } }
    let(:package_build_status) { described_class.new(package) }

    context 'no job history' do
      it { expect { subject }.not_to raise_error }
      it { expect(subject.instance_variable_get(:@everbuilt)).to be_falsey }
    end

    context 'with job history' do
      let(:md5sum) { 'c157a79031e1c40f85931829bc5fc552' }
      let(:local_job_history) do
        LocalJobHistory.new(
          arch: arch_name,
          repository: repo_hash['name'],
          verifymd5: md5sum,
          srcmd5: md5sum,
          code: 'succeeded'
        )
      end

      before do
        package_build_status.instance_variable_set(:@srcmd5, md5sum)
        allow(Backend::Api::BuildResults::JobHistory).to receive(:for_package).and_return([local_job_history])
        subject
      end

      it { expect(package_build_status.instance_variable_get(:@everbuilt)).to be_truthy }
    end
  end
end
