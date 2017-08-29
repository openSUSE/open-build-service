require 'rails_helper'

RSpec.describe 'rake db' do
  describe '#convert_notifications_serialization' do
    let!(:yaml) { "---\nhello: world\nhow:\n- are\n- you\n- today?\nim: fine thanks\n" }
    let!(:notification) { create(:notification, type: 'Notification::RssFeedItem') }
    let!(:task) { Rake::Task['db:convert_notifications_serialization'] }

    before do
      sql = "UPDATE `notifications` SET `event_payload` = '#{yaml}' WHERE id = #{notification.id}"
      ActiveRecord::Base.connection.execute(sql)
    end

    subject! { task.execute }

    it 'converts the notifications event_payload from yaml to json' do
      json_hash = { "hello" => "world", "how" => ["are", "you", "today?"], "im" => "fine thanks"}
      expect(Notification.first.event_payload).to eq(json_hash)
    end
  end
end
