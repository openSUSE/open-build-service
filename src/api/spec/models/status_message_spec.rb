require 'rails_helper'

RSpec.describe StatusMessage do
  let(:admin_user) { create(:admin_user, login: 'admin') }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_presence_of(:message) }
  end

  describe '.from_xml' do
    before do
      allow(User).to receive(:session!).and_return(admin_user)
    end

    context 'xml is valid' do
      let(:xml) { '<status_message id="4"><message>foo</message><severity>information</severity></status_message>' }
      let(:status_message) { StatusMessage.from_xml(xml) }

      it { expect { status_message }.not_to raise_error }
      it { expect(status_message).to be_a(StatusMessage) }
    end

    context 'xml is invalid' do
      it { expect { StatusMessage.from_xml('') }.to raise_error(ActiveRecord::RecordInvalid) }
    end
  end

  describe '.communication_scopes_for_current_user' do
    context 'when user is nobody' do
      it { expect(StatusMessage.communication_scopes_for_current_user).to match_array([:all_users]) }
    end

    context 'when user is in beta' do
      let(:user) { create(:confirmed_user, in_beta: true, in_rollout: true) }

      before do
        login(user)
      end

      it { expect(StatusMessage.communication_scopes_for_current_user).to match_array([:all_users, :in_beta_users, :in_rollout_users, :logged_in_users]) }
    end

    context 'when user is admin' do
      let(:user) { create(:admin_user, in_beta: true, in_rollout: false) }

      before do
        login(user)
      end

      it { expect(StatusMessage.communication_scopes_for_current_user).to match_array([:all_users, :in_beta_users, :admin_users, :logged_in_users]) }
    end
  end

  describe '.latest_for_current_user' do
    context 'with user is nobody' do
      context 'when there are not announcements at all' do
        it 'returns nil' do
          expect(StatusMessage.latest_for_current_user).to be_nil
        end
      end

      context 'when there are not announcements in her scope' do
        let!(:status_message_for_logged_in) { create(:status_message, severity: 'announcement', communication_scope: :logged_in_users) }

        it 'returns nil' do
          expect(StatusMessage.latest_for_current_user).to be_nil
        end
      end

      context 'when there is more than one announcement in her scope' do
        let!(:first_status_message) { create(:status_message, severity: 'announcement', communication_scope: :all_users, created_at: 1.day.ago) }
        let!(:second_status_message) { create(:status_message, severity: 'announcement', communication_scope: :all_users) }

        it 'returns the newest one' do
          expect(StatusMessage.latest_for_current_user).to eq(second_status_message)
        end
      end
    end

    context 'with a beta user' do
      let(:user) { create(:confirmed_user, in_beta: true, in_rollout: false) }

      context 'when there are not announcements at all' do
        it 'returns nil' do
          expect(StatusMessage.latest_for_current_user).to be_nil
        end
      end

      context 'when there is more than one announcement in her scope' do
        let!(:status_message_for_in_beta) { create(:status_message, severity: 'announcement', communication_scope: :in_beta_users, created_at: 1.day.ago) }
        let!(:status_message_for_all) { create(:status_message, severity: 'announcement', communication_scope: :all_users) } # now

        before do
          login(user)
        end

        context 'before acknowledgement' do
          it 'returns the most recent one, the one for all users' do
            expect(StatusMessage.latest_for_current_user).to eq(status_message_for_all)
          end
        end

        context 'after acknowledgement' do
          before do
            status_message_for_all.acknowledge!
          end

          it 'returns nil' do
            expect(StatusMessage.latest_for_current_user).to be_nil
          end
        end
      end

      context 'when the newest announcement is not in her scope' do
        let!(:status_message_for_in_beta) { create(:status_message, severity: 'announcement', communication_scope: :in_beta_users, created_at: 1.day.ago) }
        let!(:status_message_for_rollout) { create(:status_message, severity: 'announcement', communication_scope: :in_rollout_users) } # now

        before do
          login(user)
        end

        it 'returns the most recent one in its scope, the one for beta users' do
          expect(StatusMessage.latest_for_current_user).to eq(status_message_for_in_beta)
        end
      end
    end
  end

  describe '#acknowledge!' do
    context 'when there is a previous acknowledgement' do
      let(:user) { create(:confirmed_user, in_beta: true, in_rollout: false) }
      let!(:status_message) { create(:status_message, severity: 'announcement', communication_scope: :all_users) }

      before do
        login(user)
        status_message.acknowledge!
      end

      subject(:acknowledge) { status_message.acknowledge! }

      it 'does not raise an exception while acknowledging the status message twice' do
        expect { acknowledge }.not_to raise_error
      end

      it 'returns false' do
        expect(acknowledge).to be false
      end
    end
  end

  describe 'acknowledged?' do
    let(:user) { create(:confirmed_user, in_beta: true, in_rollout: false) }
    let!(:status_message) { create(:status_message, severity: 'announcement', communication_scope: :all_users) }

    before { login(user) }

    context 'when the status message is not acknowledged yet' do
      it { expect(status_message.acknowledged?).to be false }
    end

    context 'when the status message is already acknowledged' do
      before { status_message.acknowledge! }

      it { expect(status_message.acknowledged?).to be true }
    end
  end
end
