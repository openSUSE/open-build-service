RSpec.describe FetchRemoteDistributionsJob do
  describe '#perform' do
    subject { described_class.new.perform }

    let(:distributions_xml) { file_fixture('distributions.xml').read }
    let(:first_remote) { create(:remote_project, name: 'FirstRemote') }
    let(:second_remote) { create(:remote_project, name: 'SecondRemote') }
    let!(:cached_distribution) { create(:distribution, project: 'FirstRemote:openSUSE:Leap', remote: true) }

    before do
      allow(Project).to receive(:remote).and_return([first_remote, second_remote])
      allow(Project::RemoteURL).to receive(:load).with(second_remote, '/distributions.xml').and_return(distributions_xml)
    end

    context 'when a remote project fails' do
      before do
        allow(Project::RemoteURL).to receive(:load).with(first_remote, '/distributions.xml').and_return(nil)
      end

      it { is_expected.to be(false) }

      it 'refreshes the remote projects after it' do
        expect { subject }.to change { Distribution.remote.for_project(second_remote.name).count }.from(0).to(3)
      end

      it 'keeps the cached distributions of the failing remote project' do
        subject
        expect(Distribution.remote.for_project(first_remote.name)).to contain_exactly(cached_distribution)
      end
    end

    context 'when all remote projects succeed' do
      before do
        allow(Project::RemoteURL).to receive(:load).with(first_remote, '/distributions.xml').and_return(distributions_xml)
      end

      it { is_expected.to be(true) }

      it 'refreshes all remote projects' do
        subject
        expect(Distribution.remote.for_project(first_remote.name)).not_to include(cached_distribution)
      end
    end
  end
end
