RSpec.describe NotificationPackage do
  describe '#link_text' do
    context 'when the notification is about a build failure' do
      let(:notification) do
        create(
          :notification_for_package,
          :build_failure,
          event_payload: {
            project: 'OBS:Server:Unstable',
            package: 'obs-server',
            repository: 'openSUSE_Factory_zSystems',
            arch: 's390x',
            reason: 'source change'
          }
        )
      end

      it { expect(notification.link_text).to eq('OBS:Server:Unstable/obs-server failed to build') }
    end
  end
end
