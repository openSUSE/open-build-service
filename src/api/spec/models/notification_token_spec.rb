require 'spec_helper'

RSpec.describe NotificationToken do
  subject { notification }

  let(:user) { create(:confirmed_user) }
  let(:token) { create(:token, :scm_token, user: user) }
  let(:event_payload) do
    { 'token_id' => token.id, 'token_name' => token.name, 'workflow_run_id' => 123 }
  end
  let(:notification) do
    create(:notification, type: 'NotificationToken', event_payload: event_payload,
                          notifiable: token, subscriber: user)
  end

  describe '#description' do
    it { expect(subject.description).to eq('Token disabled') }
  end

  describe '#excerpt' do
    it { expect(subject.excerpt).to eq("Your token '#{token.name}' was disabled") }
  end

  describe '#link_text' do
    it { expect(subject.link_text).to eq('Token') }
  end

  describe '#link_path' do
    it 'returns the token path' do
      expect(subject.link_path).to eq("/tokens/#{token.id}?notification_id=#{notification.id}")
    end
  end

  describe '#avatar_objects' do
    it { expect(subject.avatar_objects).to eq([user]) }
  end
end
