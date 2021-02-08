require 'rails_helper'

RSpec.describe CleanupNotificationsJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    it 'only deletes old notifications' do
      create(:notification, :stale)
      create(:notification)

      expect { described_class.new.perform }.to change(Notification, :count).by(-1)
    end
  end
end
