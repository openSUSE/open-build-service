RSpec.describe NotificationToken do
  describe '#description' do
    subject { notification.description }

    let(:user) { create(:confirmed_user) }
    let(:token) { create(:workflow_token, description: 'My API Token') }
    let(:notification) do
      NotificationToken.create!(
        event_type: 'Event::TokenDisabled',
        event_payload: { 'token_id' => token.id },
        subscription_receiver_role: 'token_executor',
        notifiable: token,
        subscriber: user
      )
    end

    it { expect(subject).to include('My API Token') }
    it { expect(subject).to include('disabled') }

    context 'when token has no description' do
      let(:token) { create(:workflow_token, description: '') }

      it { expect(subject).to include('Token') }
    end
  end

  describe '#excerpt' do
    subject { notification.excerpt }

    let(:user) { create(:confirmed_user) }
    let(:token) { create(:workflow_token) }
    let(:event_payload) do
      { 'token_id' => token.id, 'summary' => 'Failed to report back to GitHub: Unauthorized request.' }
    end
    let(:notification) do
      NotificationToken.create!(
        event_type: 'Event::TokenDisabled',
        event_payload: event_payload,
        subscription_receiver_role: 'token_executor',
        notifiable: token,
        subscriber: user
      )
    end

    it { expect(subject).to eq('Failed to report back to GitHub: Unauthorized request.') }

    context 'when summary is missing' do
      let(:event_payload) { {} }

      it { expect(subject).to eq('Token was disabled due to authorization failure') }
    end
  end

  describe '#avatar_objects' do
    subject { notification.avatar_objects }

    let(:user) { create(:confirmed_user) }
    let(:token) { create(:workflow_token) }
    let(:notification) do
      NotificationToken.create!(
        event_type: 'Event::TokenDisabled',
        event_payload: { 'token_id' => token.id },
        subscription_receiver_role: 'token_executor',
        notifiable: token,
        subscriber: user
      )
    end

    it { expect(subject).to contain_exactly(token.executor) }

    context 'when token is deleted' do
      before do
        token.destroy
        notification.reload
        notification.association(:notifiable).reload
      end

      it { expect(subject).to be_empty }
    end
  end

  describe '#link_text' do
    subject { notification.link_text }

    let(:user) { create(:confirmed_user) }
    let(:token) { create(:workflow_token) }
    let(:notification) do
      NotificationToken.create!(
        event_type: 'Event::TokenDisabled',
        event_payload: { 'token_id' => token.id },
        subscription_receiver_role: 'token_executor',
        notifiable: token,
        subscriber: user
      )
    end

    it { expect(subject).to eq('Token') }
  end

  describe '#link_path' do
    subject { notification.link_path }

    let(:user) { create(:confirmed_user) }
    let(:token) { create(:workflow_token) }
    let(:notification) do
      NotificationToken.create!(
        event_type: 'Event::TokenDisabled',
        event_payload: { 'token_id' => token.id },
        subscription_receiver_role: 'token_executor',
        notifiable: token,
        subscriber: user
      )
    end

    it { expect(subject).to eq(Rails.application.routes.url_helpers.token_path(token)) }

    context 'when notifiable is blank' do
      let(:notification) do
        NotificationToken.create!(
          type: 'NotificationToken',
          event_type: 'Event::TokenDisabled',
          event_payload: { 'token_id' => 999 },
          subscription_receiver_role: 'token_executor',
          notifiable: nil,
          subscriber: user
        )
      end

      it { expect(subject).to be_nil }
    end
  end
end
