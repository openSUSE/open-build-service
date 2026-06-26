RSpec.describe RepositoryArchitecture do
  describe '.build_id' do
    subject { repository_architecture.build_id }

    let(:repository_architecture) { create(:repository_architecture) }
    let(:repository) { repository_architecture.repository }
    let(:project) { repository.project.name }
    let(:architecture) { repository_architecture.architecture.name }

    let(:good_response) { '<status code="finished"><buildid>1</buildid></status>' }
    let(:busy_response) { '<status code="building"/>' }

    it 'fetches from backend' do
      stub_request(:get, "#{CONFIG['source_url']}/build/#{project}/#{repository.name}/#{architecture}?view=status").and_return(body: good_response)
      expect(subject).to eq('1')
    end

    it 'does not crash' do
      stub_request(:get, "#{CONFIG['source_url']}/build/#{project}/#{repository.name}/#{architecture}?view=status").and_return(body: busy_response)
      expect(subject).to be_nil
    end
  end
end
