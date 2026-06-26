RSpec.describe UpdateNotificationEvents do
  let!(:admin) { create(:admin_user, login: 'Admin') }
  let(:notifications) do
    <<-RESPONSE
        <notifications next="3">
          <notification type="SRCSRV_CREATE_PROJECT" time="1539445101">
            <data key="project">project_1</data>
            <data key="sender">_nobody_</data>
          </notification>
          <notification type="SRCSRV_CREATE_PACKAGE" time="1539445101">
            <data key="package">multibuild</data>
            <data key="project">project_1</data>
            <data key="sender">_nobody_</data>
          </notification>
        </notifications>
    RESPONSE
  end

  before do
    url = "#{CONFIG['source_url']}/lastnotifications?block=1&start=1"
    stub_request(:get, url).and_return(body: notifications)
  end

  it 'fetches events' do
    UpdateNotificationEvents.new.perform
    expect(BackendInfo.lastnotification_nr).to eq(3)
  end

  context 'with configured amqp', rabbitmq: '#' do
    it 'sends events' do
      # not interested in setup messages
      empty_message_queue

      UpdateNotificationEvents.new.perform

      # SRCSRV_CREATE_PROJECT
      expect_message('opensuse.obs.project.create', '{"project":"project_1","sender":"_nobody_"}')
      expect_message('opensuse.obs.metrics', 'project.create,home=false value=1')

      # SRCSRV_CREATE_PACKAGE
      expect_message('opensuse.obs.package.create', '{"project":"project_1","package":"multibuild","sender":"_nobody_"}')
      expect_message('opensuse.obs.metrics', 'package.create,home=false value=1')

      expect_no_message
    end
  end
end
