require 'spec_helper'

RSpec.describe Event::TokenDisabled do
  subject { described_class.new(payload) }

  let(:token) { create(:token, :scm_token) }
  let(:payload) do
    { 'token_id' => token.id, 'token_name' => token.name, 'workflow_run_id' => 123, 'scm_vendor' => 'github' }
  end

  describe '#subject' do
    it 'returns the correct subject' do
      expect(subject.subject).to eq('Your Github workflow token was disabled due to authorization errors')
    end
  end

  describe '#token_executors' do
    it 'returns the token executor' do
      expect(subject.token_executors).to eq([token.user])
    end
  end

  describe '#parameters_for_notification' do
    let(:params) { subject.parameters_for_notification }

    it 'returns correct notifiable type' do
      expect(params[:notifiable_type]).to eq('Token::Workflow')
    end

    it 'returns correct notifiable id' do
      expect(params[:notifiable_id]).to eq(token.id)
    end

    it 'returns correct notification type' do
      expect(params[:type]).to eq('NotificationToken')
    end
  end
end
