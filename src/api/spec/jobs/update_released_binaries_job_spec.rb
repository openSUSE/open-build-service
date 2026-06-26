RSpec.describe UpdateReleasedBinariesJob do
  let(:binary_hash) do
    {
      'disturl' => '/foo/bar',
      'supportstatus' => 'foo',
      'binaryid' => '31337',
      'buildtime' => '1640772016',
      'binaryarch' => 'i386',
      'name' => 'foo'
    }
  end

  let(:project) { create(:project, name: 'foo') }
  let(:repository) { create(:repository, project: project) }
  let(:event) { Event::Packtrack.create(project: project.name, repo: repository.name, payload: '12345') }

  describe '.perform' do
    subject { event } # # UpdateBackendInfosJob gets scheduled when the event is created

    context 'no binary release existed before' do
      before do
        allow(Backend::Api::Server).to receive_messages(notification_payload: [binary_hash].to_json, delete_notification_payload: '')
      end

      it { expect { subject }.to change(BinaryRelease, :count).from(0).to(1) }
    end

    context 'an existing binary release should be updated' do
      let!(:binary_release) { create(:binary_release, repository: repository) }
      let(:repeated_binary_hash) do
        {
          'disturl' => binary_release.binary_disturl,
          'supportstatus' => binary_release.binary_supportstatus,
          'binaryid' => '31338', # change a value to avoid both objects to be identical
          'buildtime' => binary_release.binary_buildtime,
          'name' => binary_release.binary_name,
          'binaryarch' => binary_release.binary_arch
        }
      end

      before do
        allow(Backend::Api::Server).to receive_messages(notification_payload: [repeated_binary_hash].to_json, delete_notification_payload: '')
        subject
      end

      it { expect(BinaryRelease.first.modify_time).not_to be_nil }
      it { expect(BinaryRelease.last.binary_id).to eq('31338') }
      it { expect(BinaryRelease.last.operation).to eq('modified') }
    end
  end

  describe '.update_binary_releases_for_repository' do
    context 'with empty json' do
      it { expect { described_class.new.send(:update_binary_releases_for_repository, repository, []) }.not_to raise_error }
    end

    context 'with a repository to be released' do
      let!(:binary_release) { create(:binary_release, repository: repository) }
      let(:repeated_binary_hash) do
        {
          'disturl' => binary_release.binary_disturl,
          'supportstatus' => binary_release.binary_supportstatus,
          'binaryid' => binary_release.binary_id,
          'buildtime' => binary_release.binary_buildtime,
          'name' => binary_release.binary_name,
          'binaryarch' => binary_release.binary_arch
        }
      end

      it { expect { described_class.new.send(:update_binary_releases_for_repository, repository, [repeated_binary_hash]) }.not_to raise_error }
    end
  end

  describe '.old_and_new_binary_identical?' do
    subject { described_class.new.send(:old_and_new_binary_identical?, binary_release, binary_hash) }

    context 'old and new binary are identical' do
      let(:binary_release) do
        BinaryRelease.new(
          binary_disturl: binary_hash['disturl'],
          binary_supportstatus: binary_hash['supportstatus'],
          binary_id: binary_hash['binaryid'],
          binary_buildtime: Time.strptime(binary_hash['buildtime'], '%s')
        )
      end

      it { expect(subject).to be_truthy }
    end

    context 'old and new binary are not identical' do
      let(:binary_release) do
        BinaryRelease.new(
          binary_disturl: binary_hash['disturl'],
          binary_supportstatus: binary_hash['supportstatus'],
          binary_id: binary_hash['binaryid'],
          binary_buildtime: Time.zone.now
        )
      end

      it { expect(subject).to be_falsey }
    end
  end
end
