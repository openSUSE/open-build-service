# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20170831143534_convert_notifications_event_payload_to_json.rb')

RSpec.describe ConvertNotificationsEventPayloadToJson do
  describe '.up' do
    let!(:yaml) { "---\nhello: world\nhow:\n- are\n- you\n- today?\nim: fine thanks\n" }
    let!(:notification) { create(:notification, type: 'Notification::RssFeedItem') }

    before do
      sql = "UPDATE `notifications` SET `event_payload` = '#{yaml}' WHERE id = #{notification.id}"
      ActiveRecord::Base.connection.execute(sql)
    end

    subject! { ConvertNotificationsEventPayloadToJson.up }

    it 'converts the notifications event_payload from yaml to json' do
      json_hash = { 'hello' => 'world', 'how' => ['are', 'you', 'today?'], 'im' => 'fine thanks' }
      expect(Notification.first.event_payload).to eq(json_hash)
    end
  end
end
