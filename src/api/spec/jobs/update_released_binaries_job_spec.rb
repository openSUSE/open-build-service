RSpec.describe UpdateReleasedBinariesJob do
  let(:notification_payload) { build(:notification_payload) }

  let(:project) { create(:project, name: 'foo') }
  let(:repository) { create(:repository, project: project) }
  let(:event) { Event::Packtrack.create(project: project.name, repo: repository.name, payload: '12345') }

  describe '.perform' do
    subject { event } # # UpdateBackendInfosJob gets scheduled when the event is created

    context 'a binary release should be created' do
      before do
        allow(Backend::Api::Server).to receive_messages(notification_payload: [notification_payload].to_json, delete_notification_payload: '')
      end

      it { expect { subject }.to change(BinaryRelease, :count).from(0).to(1) }
    end

    context 'an existing binary release should be updated' do
      let!(:binary_release) { create(:binary_release, repository: repository, binaryid: 'hans') }
      let(:notification_payload) do
        binary_release.slice(:disturl,
                             :supportstatus,
                             :buildtime,
                             :name,
                             :binaryarch,
                             :version,
                             :release).merge(binaryid: 'franz')
      end

      before do
        allow(Backend::Api::Server).to receive_messages(notification_payload: [notification_payload].to_json, delete_notification_payload: '')
        subject
      end

      it { expect(BinaryRelease.first.modify_time).not_to be_nil }
      it { expect(BinaryRelease.first.binaryid).to eq('hans') }
      it { expect(BinaryRelease.last.binary_id).to eq('franz') }
      it { expect(BinaryRelease.last.operation).to eq('modified') }
    end

    context 'a release_package should be assigned' do
      let(:package) { create(:package) }
      let(:notification_payload) { build(:notification_payload, package: package.name, project: package.project.name) }

      before do
        allow(Backend::Api::Server).to receive_messages(notification_payload: [notification_payload].to_json, delete_notification_payload: '')
        subject
      end

      it { expect(BinaryRelease.last.release_package).to eq(package) }
    end

    context 'a flavor should be assigned' do
      let(:package) { create(:package) }
      let(:notification_payload) { build(:notification_payload, package: "#{package.name}:hans", project: package.project.name) }

      before do
        allow(Backend::Api::Server).to receive_messages(notification_payload: [notification_payload].to_json, delete_notification_payload: '')
        subject
      end

      it { expect(BinaryRelease.last.flavor).to eq('hans') }
    end

    context 'an binary_maintainer should be assigned' do
      let(:patchinfo) { file_fixture('patchinfo.xml').read }
      let(:notification_payload) { build(:notification_payload, :with_patchinfo) }

      before do
        allow(Backend::Api::Sources::Project).to receive(:patchinfo).and_return(patchinfo)
        allow(Backend::Api::Server).to receive_messages(notification_payload: [notification_payload].to_json, delete_notification_payload: '')
        subject
      end

      it { expect(BinaryRelease.last.binary_maintainer).to eq('adrian@suse.de') }
    end

    context 'a on_medium should be assigned' do
      let(:medium) { build(:notification_payload, :medium) }
      let(:on_medium) { build(:notification_payload, medium: medium[:ismedium]) }

      before do
        allow(Backend::Api::Server).to receive_messages(notification_payload: [medium, on_medium].to_json, delete_notification_payload: '')
        subject
      end

      it { expect(BinaryRelease.first.on_medium).to be_nil }
      it { expect(BinaryRelease.last.medium).to eq(BinaryRelease.first.binary_name) }
      it { expect(BinaryRelease.last.on_medium).to eq(BinaryRelease.first) }
    end
  end

  describe '.old_and_new_binary_identical?' do
    subject { described_class.new.send(:old_and_new_binary_identical?, old_binary_release, new_binary_release) }

    context 'old and new binary are identical' do
      let(:old_binary_release) { create(:binary_release) }
      let(:new_binary_release) { old_binary_release }

      it { expect(subject).to be_truthy }
    end

    context 'old and new binary are not identical' do
      let(:old_binary_release) { build(:binary_release) }
      let(:new_binary_release) { build(:binary_release) }

      it { expect(subject).to be_falsey }
    end

    context 'old binary without binaryid' do
      let(:old_binary_release) { build(:binary_release, binaryid: nil) }
      let(:new_binary_release) do
        build(:binary_release, disturl: old_binary_release.disturl,
                               supportstatus: old_binary_release.supportstatus,
                               buildtime: old_binary_release.buildtime,
                               binaryid: 'hans')
      end

      it { expect(subject).to be_truthy }
    end
  end
end
