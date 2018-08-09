require 'rails_helper'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe EventMailer, vcr: true do
  # Needed for X-OBS-URL
  before do
    allow_any_instance_of(Configuration).to receive(:obs_url).and_return('https://build.example.com')
  end

  let!(:receiver) { create(:confirmed_user) }

  describe '.event' do
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
      let(:mail) { EventMailer.event(event.subscribers, event).deliver_now }

      context 'when source project does not exist' do
        before do
          login(receiver)
          source_package.project.destroy
        end

        it 'does not get delivered' do
          expect(ActionMailer::Base.deliveries).not_to include(mail)
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
      let(:mail) { EventMailer.event(Event::CommentForProject.last.subscribers, Event::CommentForProject.last).deliver_now }

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
        expected_html = "<p>Hey <a href='https://build.example.com/user/show/#{receiver.login}'>@#{receiver.login}</a> "
        expected_html += "how are things? Look at <a href='https://build.example.com/project/show/apache'>bug</a> please."
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
        let(:mail) { EventMailer.event(Event::CommentForProject.last.subscribers, Event::CommentForProject.last).deliver_now }

        it 'does not send to the originator' do
          expect(mail.to).not_to include(originator.email)
        end
      end

      context 'when comment contains emoji' do
        let!(:default_subscription) { create(:event_subscription_comment_for_project_without_subscriber) }
        let(:vip) { create(:confirmed_user) }
        let!(:comment) { create(:comment_project, body: "I ❤️ @#{vip.login}!") }

        it { expect(mail.text_part.body.encoded).to include("I ❤️ [@#{vip.login}](https://build.example.com/user/show/") }
        it { expect(mail.html_part.to_s).to include("I =E2=9D=A4=EF=B8=8F <a href=3D'https://build.example.com/user/sh=\now/#{vip.login}'>@#{vip.login}</a>") }
      end
    end
  end
end
