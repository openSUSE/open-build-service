RSpec.describe Webui::NotificationHelper do
  describe '#truncate_to_first_new_line' do
    context 'when the text is nil' do
      it {  expect(truncate_to_first_new_line(nil)).to eql('') }
    end

    context 'when the text is empty string' do
      it { expect(truncate_to_first_new_line('')).to eql('') }
    end

    context 'when text has no newline' do
      it {
        expect(truncate_to_first_new_line('some text without newline'))
          .to eql('some text without newline')
      }
    end

    context 'when text has newline' do
      it {
        expect(truncate_to_first_new_line('some text with a first line here\nthis is the second line'))
          .to eql('some text with a first line here\\nthis is the second line')
      }
    end

    context 'when text is long' do
      it {
        expect(truncate_to_first_new_line('some text with a long long long long long long long long long long long long long long long long long first line\nand a second line'))
          .to eql('some text with a long long long long long long long long long long long long long long long long ...')
      }
    end
  end

  describe '#notification_icon' do
    context 'when the notification is about a request' do
      let(:notification) { create(:notification_for_request, :request_created) }

      it { expect(notification_icon(notification)).to include('fa-code-pull-request') }
    end

    context 'when the notification is about a relationship' do
      let(:notification) { create(:notification_for_project, :relationship_create_for_project) }

      it { expect(notification_icon(notification)).to include('fa-user-tag') }
    end
  end

  describe '#description' do
    context 'when the notification is about a report for user' do
      let(:spammer) { create(:confirmed_user, login: 'trouble_maker') }
      let(:report_for_user) { create(:report, reportable: spammer, reason: 'This is a spammer!') }
      let(:notification) { create(:notification_for_report, :web_notification, notifiable: report_for_user, event_type: 'Event::ReportForUser', subscriber: spammer) }

      it { expect(description(notification)).to include('created a report') }
    end

    context 'when the notification is about a report for comment' do
      let(:spammer) { create(:confirmed_user, login: 'trouble_maker') }
      let(:project) { create(:project, name: 'factory') }
      let(:comment_on_project) { create(:comment_project, commentable: project, user: spammer) }
      let(:report_for_comment) { create(:report, reportable: comment_on_project, reason: 'This is spam!') }
      let(:notification) { create(:notification_for_report, :web_notification, notifiable: report_for_comment, event_type: 'Event::ReportForComment', subscriber: spammer) }

      it { expect(description(notification)).to include('created a report for comment') }
    end

    context 'when the notification is not related to report' do
      let(:notification) { create(:notification_for_comment, :comment_for_project, event_type: 'Event::CommentOnPackage') }
      let(:comment_description) { notification.notifiable.commentable.name }

      it { expect(description(notification)).to include(comment_description) }
    end
  end
end
