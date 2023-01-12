require 'rails_helper'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe EventMailer, vcr: true do
  # Needed for X-OBS-URL
  before do
    allow_any_instance_of(Configuration).to receive(:obs_url).and_return('https://build.example.com')
    allow_any_instance_of(BsRequestAction).to receive(:contains_change?).and_return(true)
  end

  let!(:receiver) { create(:confirmed_user) }

  describe '.notification_email' do
    context 'for an event of type Event::Request' do
      let(:source_project) { create(:project, name: 'source_project') }
      let(:source_package) { create(:package_with_file, name: 'source_package', project: source_project) }
      let(:target_project) { create(:project, name: 'target_project', maintainer: receiver) }
      let(:target_package) { create(:package_with_revisions, name: 'target_package', project: target_project) }
      let(:bs_request_action_submit) do
        create(:bs_request_action_submit,
               source_package: source_package.name,
               source_project: source_project.name,
               target_project: target_project.name,
               target_package: target_package.name)
      end
      # It is not possible to use the bs_request_action_submit factory as it creates the bs_request_action
      # in an after create hook which creates a wrong Event::RequestCreate object
      let!(:bs_request) do
        create(:bs_request, bs_request_actions: [bs_request_action_submit])
      end
      let(:event) { Event::RequestCreate.first }
      let(:originator) { event.originator }
      let!(:subscription) { create(:event_subscription_request_created, user: receiver) }
      let(:mail) { EventMailer.with(subscribers: event.subscribers, event: event).notification_email.deliver_now }

      context 'when source project does not exist' do
        before do
          login(receiver)
          source_package.project.destroy
        end

        it 'the email also gets delivered' do
          expect(ActionMailer::Base.deliveries).to include(mail)
        end
      end

      it 'uses default for FROM if display name does not exist' do
        allow_any_instance_of(Event::RequestCreate).to receive(:originator).and_return(nil)
        expect(mail.from).to include('unconfigured@openbuildservice.org')
        expect(mail['From'].value).to eq('OBS Notification <unconfigured@openbuildservice.org>')
      end

      it 'uses display name for FROM if originator exists' do
        expect(mail.from).to include(originator.email)
        expect(mail['From'].value).to eq(originator.display_name)
      end
    end

    context 'for an event of type Event::CommentForProject' do
      let!(:subscription) { create(:event_subscription_comment_for_project, user: receiver) }
      let!(:comment) { create(:comment_project, body: "Hey @#{receiver.login} how are things? Look at [bug](/project/show/apache) please.") }
      let(:originator) { comment.user }
      let(:mail) { EventMailer.with(subscribers: Event::CommentForProject.last.subscribers, event: Event::CommentForProject.last).notification_email.deliver_now }

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'has subscribers' do
        expect(mail.to).to eq(Event::CommentForProject.last.subscribers.map(&:email))
      end

      it 'has a subject' do
        expect(mail.subject).to eq("New comment in project #{comment.commentable.name} by #{originator.login}")
      end

      it 'renders links absolute' do
        expected_html = "<p>Hey <a href=\"https://build.example.com/users/#{receiver.login}\">@#{receiver.login}</a> "
        expected_html += 'how are things? Look at <a href="https://build.example.com/project/show/apache">bug</a> please.'
        expect(mail.html_part.to_s).to include(expected_html)
      end

      it 'has custom headers' do
        expect(mail['X-OBS-Request-Commenter'].value).to eq(originator.login)
        expect(mail['Message-ID'].value).to eq('<notrandom@build.example.com>')
      end

      it 'has the default headers' do
        expect(mail['Precedence'].value).to eq('bulk')
        expect(mail['X-Mailer'].value).to eq('OBS Notification System')
        expect(mail['X-OBS-URL'].value).to eq('https://build.example.com')
        expect(mail['Auto-Submitted'].value).to eq('auto-generated')
        expect(mail['Return-Path'].value).to eq('OBS Notification <unconfigured@openbuildservice.org>')
        expect(mail['Sender'].value).to eq('OBS Notification <unconfigured@openbuildservice.org>')
      end

      context 'when originator is subscribed' do
        let!(:originator_subscription) { create(:event_subscription_comment_for_project, user: originator) }
        let(:mail) { EventMailer.with(subscribers: Event::CommentForProject.last.subscribers, event: Event::CommentForProject.last).notification_email.deliver_now }

        it 'does not send to the originator' do
          expect(mail.to).not_to include(originator.email)
        end
      end

      context 'when comment contains emoji' do
        let!(:default_subscription) { create(:event_subscription_comment_for_project_without_subscriber) }
        let(:vip) { create(:confirmed_user) }
        let!(:comment) { create(:comment_project, body: "I ❤️ @#{vip.login}!") }

        it { expect(mail.text_part.body.encoded).to include("I ❤️ @#{vip.login}") }
        it { expect(mail.html_part.to_s).to include('I =E2=9D=A4=EF=B8=8F <a href=3D"https://build.example.com/users/') }
      end
    end

    context 'for an event of type Event::RelationshipCreate' do
      let(:who) { create(:confirmed_user) }
      let(:project) { create(:project) }
      let(:group) { create(:group_with_user, user: receiver, email: nil) }
      let!(:subscription) { create(:event_subscription_relationship_create, user: receiver) }
      let(:mail) { EventMailer.with(subscribers: Event::RelationshipCreate.last.subscribers, event: Event::RelationshipCreate.last).notification_email.deliver_now }

      before do
        login(receiver)
      end

      context 'when a user is added to a project' do
        before do
          Event::RelationshipCreate.create!(who: who.login, user: receiver.login, project: project.name, role: 'reviewer')
        end

        it 'gets delivered' do
          expect(ActionMailer::Base.deliveries).to include(mail)
        end

        it 'sends an email as the user from which the event originates' do
          expect(mail.from).to include(who.email)
        end

        it 'sends an email to the subscribed user' do
          expect(mail.to).to include(receiver.email)
        end

        it 'contains the correct text' do
          expect(mail.body.encoded).to include("#{who} made you reviewer of #{project}")
          expect(mail.body.encoded).to include("Visit https://build.example.com/project/users/#{project}")
        end

        it 'renders link to the users page' do
          expected_html = "made you reviewer of <a href=\"https://build.example.com/project/users/#{project}\">#{project}</a>"
          expect(mail.html_part.to_s).to include(expected_html)
        end
      end

      context 'when a group is added to a project' do
        before do
          Event::RelationshipCreate.create!(who: who.login, group: group.title, project: project.name, role: 'maintainer')
        end

        it 'gets delivered' do
          expect(ActionMailer::Base.deliveries).to include(mail)
        end

        it 'sends an email as the user from which the event originates' do
          expect(mail.from).to include(who.email)
        end

        it 'sends an email to the user belonging to the subscribed group' do
          expect(mail.to).to include(receiver.email)
        end

        it 'contains the correct text' do
          expect(mail.body.encoded).to include("#{who} made #{group} maintainer of #{project}")
          expect(mail.body.encoded).to include("Visit https://build.example.com/project/users/#{project}")
        end

        it 'renders link to the users page' do
          expected_html = "made #{group} maintainer of <a href=\"https://build.example.com/project/users/#{project}\">#{project}</a>"
          expect(mail.html_part.to_s).to include(expected_html)
        end
      end
    end

    context 'for an event of type Event::RelationshipDelete' do
      let(:who) { create(:confirmed_user) }
      let(:project) { create(:project) }
      let(:group) { create(:group_with_user, user: receiver, email: nil) }
      let!(:subscription) { create(:event_subscription_relationship_delete, user: receiver) }
      let(:mail) { EventMailer.with(subscribers: Event::RelationshipDelete.last.subscribers, event: Event::RelationshipDelete.last).notification_email.deliver_now }

      before do
        login(receiver)
      end

      context 'when a user is added to a project' do
        before do
          Event::RelationshipDelete.create!(who: who.login, user: receiver.login, project: project.name, role: 'reviewer')
        end

        it 'gets delivered' do
          expect(ActionMailer::Base.deliveries).to include(mail)
        end

        it 'sends an email as the user from which the event originates' do
          expect(mail.from).to include(who.email)
        end

        it 'sends an email to the subscribed user' do
          expect(mail.to).to include(receiver.email)
        end

        it 'contains the correct text' do
          expect(mail.body.encoded).to include("#{who} removed you as reviewer of #{project}")
          expect(mail.body.encoded).to include("Visit https://build.example.com/project/users/#{project}")
        end

        it 'renders link to the users page' do
          expected_html = "removed you as reviewer of <a href=\"https://build.example.com/project/users/#{project}\">#{project}</a>"
          expect(mail.html_part.to_s).to include(expected_html)
        end
      end

      context 'when a group is added to a project' do
        before do
          Event::RelationshipDelete.create!(who: who.login, group: group.title, project: project.name, role: 'maintainer')
        end

        it 'gets delivered' do
          expect(ActionMailer::Base.deliveries).to include(mail)
        end

        it 'sends an email as the user from which the event originates' do
          expect(mail.from).to include(who.email)
        end

        it 'sends an email to the user belonging to the subscribed group' do
          expect(mail.to).to include(receiver.email)
        end

        it 'contains the correct text' do
          expect(mail.body.encoded).to include("#{who} removed #{group} as maintainer of #{project}")
          expect(mail.body.encoded).to include("Visit https://build.example.com/project/users/#{project}")
        end

        it 'renders link to the users page' do
          expected_html = "removed #{group} as maintainer of <a href=\"https://build.example.com/project/users/#{project}\">#{project}</a>"
          expect(mail.html_part.to_s).to include(expected_html)
        end
      end
    end

    context 'when the subscriber has no email' do
      let(:group) { create(:group, email: nil) }
      let(:event) { Event::RequestCreate.first }
      let(:subscribers) { [group] }

      subject! { EventMailer.with(subscribers: subscribers, event: event).notification_email.deliver_now }

      it 'does not get delivered' do
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context 'when trying to compose an email containing invalid byte sequences' do
      let(:expanded_payload) do
        {
          'project' => 'project_2',
          'package' => 'package_2',
          'repository' => 'repository_2',
          'arch' => 'i586',
          'sender' => from.login
        }
      end
      let(:from) { create(:confirmed_user) }
      let(:recipient) { create(:confirmed_user) }
      let(:event_stub) { Event::BuildFail.new(expanded_payload) }
      let(:mail) { EventMailer.with(subscribers: [recipient], event: event_stub).notification_email }
      let(:faillog) { "invalid byte sequence ->\xD3'" }

      before do
        allow(event_stub).to receive(:faillog).and_return(faillog)
        allow(event_stub).to receive(:payload).and_return(expanded_payload)
      end

      it 'renders the headers' do
        expect(mail.subject).to have_text('Build failure of project_2/package_2 in repository_2/i586')
        expect(mail.to).to eq([recipient.email])
        expect(mail.from).to eq([from.email])
      end

      context 'and there is a payload' do
        it 'renders the body' do
          expect(mail.body.encoded).to have_text('Last lines of build log:')
        end
      end

      context 'but there is no payload' do
        let(:faillog) { nil }

        it 'renders the body, but does not have a build log' do
          expect(mail.body.encoded).not_to have_text('Last lines of build log:')
        end
      end
    end
  end
end
