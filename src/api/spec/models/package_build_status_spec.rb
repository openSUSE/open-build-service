require 'rails_helper'

RSpec.describe PackageBuildStatus, vcr: true do
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
    let!(:repository_hash) do
      {
        user.home_project.name => 'foo'
      }
    end

    subject { described_class.new(package).gather_target_packages(repository_hash) }

    it { expect { subject }.not_to raise_error }
    it { expect(subject).to be_a(Hash) }
  end
end
