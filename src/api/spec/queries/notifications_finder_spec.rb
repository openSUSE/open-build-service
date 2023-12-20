RSpec.describe NotificationsFinder do
  describe '#for_notifiable_type' do
    let(:user) { create(:confirmed_user) }

    subject { described_class.new }

    before { User.session = user }

    context 'when type is "read"' do
      let!(:read_notification) { create(:notification, :request_created, delivered: true) }

      it {
        expect(subject.for_notifiable_type('read'))
          .to contain_exactly(read_notification)
      }
    end

    context 'when type is "comments"' do
      let!(:notification_for_comment) { create(:notification, :comment_for_project) }

      it {
        expect(subject.for_notifiable_type('comments'))
          .to contain_exactly(notification_for_comment)
      }
    end

    context 'when type is "requests"' do
      let!(:notification_for_request) { create(:notification, :request_created, event_payload: { kind: 'for_request' }) }

      it {
        expect(subject.for_notifiable_type('requests'))
          .to contain_exactly(notification_for_request)
      }
    end

    context 'when type is "incoming_requests"' do
      let(:project) { create(:project, maintainer: user) }
      let(:bs_request) { create(:bs_request_with_submit_action, target_project: project) }
      let!(:notification_for_incoming) do
        create(:notification, :request_created,
               notifiable: bs_request)
      end

      before { User.session = user }

      it {
        expect(subject.for_notifiable_type('incoming_requests'))
          .to contain_exactly(notification_for_incoming)
      }
    end

    context 'when type is "outgoing_requests"' do
      let(:bs_request) { create(:bs_request_with_submit_action, creator: user) }
      let!(:notification_for_outgoing) do
        create(:notification, :request_created,
               notifiable: bs_request)
      end

      before { User.session = user }

      it {
        expect(subject.for_notifiable_type('outgoing_requests'))
          .to contain_exactly(notification_for_outgoing)
      }
    end

    context 'when type is "relationships_created"' do
      let!(:notification_for_relationship_created) { create(:notification, :relationship_create_for_project) }

      it {
        expect(subject.for_notifiable_type('relationships_created'))
          .to contain_exactly(notification_for_relationship_created)
      }
    end

    context 'when type is "relationships_deleted"' do
      let!(:notification_for_relationship_deleted) { create(:notification, :relationship_delete_for_project) }

      it {
        expect(subject.for_notifiable_type('relationships_deleted'))
          .to contain_exactly(notification_for_relationship_deleted)
      }
    end

    context 'when type is "build_failures"' do
      let!(:notification_for_build_failure) { create(:notification, :build_failure) }

      it {
        expect(subject.for_notifiable_type('build_failures'))
          .to contain_exactly(notification_for_build_failure)
      }
    end

    context 'when type is "reports"' do
      let!(:notification_for_report) { create(:notification, :create_report) }

      before { Flipper.enable(:content_moderation) }

      it {
        expect(subject.for_notifiable_type('reports'))
          .to contain_exactly(notification_for_report)
      }
    end

    context 'when type is "workflow_runs"' do
      let!(:notification_for_workflow) { create(:notification, :workflow_run) }

      it {
        expect(subject.for_notifiable_type('workflow_runs'))
          .to contain_exactly(notification_for_workflow)
      }
    end

    context 'when type is "appealed_decisions"' do
      let!(:notification_for_appeal) { create(:notification, :appealed_decision) }

      before { Flipper.enable(:content_moderation) }

      it {
        expect(subject.for_notifiable_type('appealed_decisions'))
          .to contain_exactly(notification_for_appeal)
      }
    end

    context 'when type is "unread"' do
      let!(:unread_notification) { create(:notification, :request_created, event_payload: { kind: 'unread' }) }

      it { expect(subject.for_notifiable_type('unread')).to contain_exactly(unread_notification) }
    end
  end
end
