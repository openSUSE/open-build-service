RSpec.describe Event::TokenDisabled do
  describe '#token_executors' do
    subject { event.token_executors }

    let(:token) { create(:workflow_token) }
    let(:event) do
      Event::TokenDisabled.create(
        token_id: token.id,
        scm_vendor: 'github',
        summary: 'Failed to report back to GitHub: Unauthorized request.',
        token_description: 'My workflow token'
      )
    end

    it { expect(subject).to contain_exactly(token.executor) }

    context 'when the token does not exist' do
      before do
        event
        token.destroy
      end

      it { expect(subject).to be_empty }
    end
  end

  describe '#subject' do
    subject { event.subject }

    let(:token) { create(:workflow_token) }

    context 'with GitHub vendor' do
      let(:event) do
        Event::TokenDisabled.create(
          token_id: token.id,
          scm_vendor: 'github',
          summary: 'Failed to report back to GitHub: Unauthorized request.',
          token_description: 'My workflow token'
        )
      end

      it { expect(subject).to eq('GitHub workflow token disabled') }
    end

    context 'with GitLab vendor' do
      let(:event) do
        Event::TokenDisabled.create(
          token_id: token.id,
          scm_vendor: 'gitlab',
          summary: 'Failed to report back to GitLab: Request forbidden.',
          token_description: 'My workflow token'
        )
      end

      it { expect(subject).to eq('GitLab workflow token disabled') }
    end

    context 'with nil vendor' do
      let(:event) do
        Event::TokenDisabled.create(
          token_id: token.id,
          scm_vendor: nil,
          summary: 'Failed to report back.',
          token_description: 'My workflow token'
        )
      end

      it { expect(subject).to eq('SCM workflow token disabled') }
    end

    context 'with unknown vendor' do
      let(:event) do
        Event::TokenDisabled.create(
          token_id: token.id,
          scm_vendor: 'bitbucket',
          summary: 'Failed to report back to Bitbucket.',
          token_description: 'My workflow token'
        )
      end

      it { expect(subject).to eq('Bitbucket workflow token disabled') }
    end
  end

  describe '#parameters_for_notification' do
    subject { event.parameters_for_notification }

    let(:token) { create(:workflow_token) }
    let(:event) do
      Event::TokenDisabled.create(
        token_id: token.id,
        scm_vendor: 'github',
        summary: 'Failed to report back to GitHub: Unauthorized request.',
        token_description: 'My workflow token'
      )
    end

    it 'includes the correct notifiable type' do
      expect(subject[:notifiable_type]).to eq('Token::Workflow')
    end

    it 'includes the correct notifiable id' do
      expect(subject[:notifiable_id]).to eq(token.id)
    end

    it 'includes the correct notification type' do
      expect(subject[:type]).to eq('NotificationToken')
    end
  end

  describe '#event_object' do
    subject { event.event_object }

    let(:token) { create(:workflow_token) }
    let(:event) do
      Event::TokenDisabled.create(
        token_id: token.id,
        scm_vendor: 'github',
        summary: 'Failed to report back to GitHub: Unauthorized request.',
        token_description: 'My workflow token'
      )
    end

    it { expect(subject).to eq(token) }

    context 'when the token does not exist' do
      before do
        event
        token.destroy
      end

      it { expect(subject).to be_nil }
    end
  end

  describe '#token_members' do
    subject { event.token_members }

    let(:executor) { create(:confirmed_user) }
    let(:member) { create(:confirmed_user) }
    let(:token) { create(:workflow_token, executor: executor) }
    let(:event) do
      Event::TokenDisabled.create(
        token_id: token.id,
        scm_vendor: 'github',
        summary: 'Failed to report back to GitHub: Unauthorized request.',
        token_description: 'My workflow token'
      )
    end

    before do
      token.users << member
    end

    it 'returns all members including shared users' do
      expect(subject).to include(member)
    end
  end
end
