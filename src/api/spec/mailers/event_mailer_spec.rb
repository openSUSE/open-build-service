RSpec.describe EventMailer, :vcr do
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
        expect(mail['From'].value).to eq("\"#{originator.realname} (#{originator.login})\" <unconfigured@openbuildservice.org>")
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
        expected_html = "<p>Hey <a href=\"https://build.example.com/users/#{receiver.login}\" rel=\"nofollow\">@#{receiver.login}</a> "
        expected_html += 'how are things? Look at <a href="https://build.example.com/project/show/apache" rel="nofollow">bug</a> please.'
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

    context 'for an event of type Event::ReportForProject' do
      let(:admin) { create(:admin_user) }
      let!(:subscription) { create(:event_subscription_report, user: admin) }
      let(:mail) { EventMailer.with(subscribers: Event::ReportForProject.last.subscribers, event: Event::ReportForProject.last).notification_email.deliver_now }
      let(:project) { create(:project, name: 'foo') }

      before do
        create(:report, reportable: project, reason: 'Because reasons')
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include('reported a project as Other for the following reason:')
        expect(mail.body.encoded).to include('Because reasons')
      end

      it 'renders link to the project page' do
        expect(mail.body.encoded).to include('<a href="https://build.example.com/project/show/foo#comments-list">foo</a>')
      end
    end

    context 'for an event of type Event::ReportForPackage' do
      let(:admin) { create(:admin_user) }
      let!(:subscription) { create(:event_subscription_report, user: admin) }
      let(:mail) { EventMailer.with(subscribers: Event::ReportForPackage.last.subscribers, event: Event::ReportForPackage.last).notification_email.deliver_now }
      let(:project) { create(:project, name: 'foo') }
      let(:package) { create(:package, name: 'bar', project: project) }

      before do
        create(:report, reportable: package, reason: 'Because reasons')
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include('reported a package as Other for the following reason:')
        expect(mail.body.encoded).to include('Because reasons')
      end

      it 'renders link to the package page' do
        expect(mail.body.encoded).to include('<a href="https://build.example.com/package/show/foo/bar#comments-list">bar</a>')
      end
    end

    context 'for an event of type Event::ReportForUser' do
      let(:admin) { create(:admin_user) }
      let!(:subscription) { create(:event_subscription_report, user: admin) }
      let(:mail) { EventMailer.with(subscribers: Event::ReportForUser.last.subscribers, event: Event::ReportForUser.last).notification_email.deliver_now }
      let(:user) { create(:user, login: 'hans') }

      before do
        create(:report, reportable: user, reason: 'Because reasons')
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include('reported a user as Other for the following reason:')
        expect(mail.body.encoded).to include('Because reasons')
      end

      it 'renders link to the user page' do
        expect(mail.body.encoded).to include('<a href="https://build.example.com/users/hans">hans</a>')
      end
    end

    context 'for an event of type Event::ReportForComment' do
      let(:admin) { create(:admin_user) }
      let!(:subscription) { create(:event_subscription_report, user: admin) }
      let(:mail) { EventMailer.with(subscribers: Event::ReportForComment.last.subscribers, event: Event::ReportForComment.last).notification_email.deliver_now }
      let(:project) { create(:project, name: 'foo') }
      let(:comment) { create(:comment_project, commentable: project) }

      before do
        create(:report, reportable: comment, reason: 'Because reasons')
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include('reported a comment as Other for the following reason:')
        expect(mail.body.encoded).to include('Because reasons')
      end

      it 'renders link to the page of the comment' do
        expect(mail.body.encoded).to include('<a href="https://build.example.com/project/show/foo#comments-list">foo</a>')
      end
    end

    context 'when the subscriber has no email' do
      subject! { EventMailer.with(subscribers: subscribers, event: event).notification_email.deliver_now }

      let(:group) { create(:group, email: nil) }
      let(:event) { Event::RequestCreate.first }
      let(:subscribers) { [group] }

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
        allow(event_stub).to receive_messages(faillog: faillog, payload: expanded_payload)
      end

      it 'renders the headers' do
        expect(mail.subject).to have_text('Build failure of project_2/package_2 in repository_2/i586')
        expect(mail.to).to eq([recipient.email])
      end

      context 'and there is a payload' do
        it 'renders the body' do
          expect(mail.body.encoded).to have_text('Last lines of build log:')
        end
      end

      context 'but there is no payload' do
        let(:faillog) { nil }

        it 'renders the body, but does not have a build log' do
          expect(mail.body.encoded).to have_no_text('Last lines of build log:')
        end
      end
    end

    context 'for an event of type Event::WorkflowRunFail' do
      let(:token) { create(:workflow_token, executor: receiver) }
      let(:workflow_run) { create(:workflow_run, token: token) }
      let!(:subscription) { create(:event_subscription_workflow_run_fail, user: receiver) }
      let(:mail) { EventMailer.with(subscribers: Event::WorkflowRunFail.last.subscribers, event: Event::WorkflowRunFail.last).notification_email.deliver_now }

      before do
        login(receiver)
      end

      context 'when the workflow run fails' do
        before do
          workflow_run.update_as_failed('Failed for whatever reason')
        end

        it 'gets delivered' do
          expect(ActionMailer::Base.deliveries).to include(mail)
        end

        it 'has a subject' do
          expect(mail.subject).to eq('Workflow run failed on Pull request')
        end

        it 'has the right subscribers' do
          expect(mail.to).to eq(Event::WorkflowRunFail.last.subscribers.map(&:email))
        end

        it 'renders links absolute' do
          expect(mail.body.encoded).to include('Check the details about this ' \
                                               "<a href=\"https://build.example.com/my/tokens/#{token.id}/workflow_runs/#{workflow_run.id}\">Workflow Run</a>")
        end

        it { expect(mail.text_part.body.to_s).to include('A workflow run failed for Pull request #1, opened') }
        it { expect(mail.html_part.body.to_s).to include('A workflow run failed for Pull request #1, opened') }
        it { expect(mail.html_part.body.to_s).to include("on repository #{workflow_run.repository_owner}/#{workflow_run.repository_name}") }
      end
    end

    context 'for an event of type Event::ClearedDecision' do
      let(:admin) { create(:admin_user) }
      let(:reporter) { create(:confirmed_user) }
      let(:report) { create(:report, reporter: reporter) }
      let(:package) { report.reportable.commentable }
      let!(:subscription) { create(:event_subscription_decision, user: reporter) }
      let(:decision) { create(:decision_cleared, moderator: admin, reason: 'This is NOT spam.', reports: [report]) }
      let(:event) { Event::ClearedDecision.last }
      let(:mail) { EventMailer.with(subscribers: event.subscribers, event: event).notification_email.deliver_now }

      before do
        login(admin)
        decision
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'is sent to the reporter' do
        expect(mail.to).to contain_exactly(reporter.email)
      end

      it 'has a subject' do
        expect(mail.subject).to eq("Cleared #{decision.reports.first.reportable&.class&.name} Report")
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include("'#{decision.moderator}' decided to clear the report. This is the reason:")
        expect(mail.body.encoded).to include('This is NOT spam.')
      end

      it 'renders link to the page of the comment' do
        expect(mail.body.encoded).to include("<a href=\"https://build.example.com/package/show/#{package.project}/#{package}#comments-list\">#{package}</a>")
      end
    end

    context 'for an event of type Event::FavoredDecision' do
      let(:admin) { create(:admin_user) }
      let(:offender) { create(:confirmed_user, login: 'offender') } # user who wrote the offensive comment
      let(:reporter) { create(:confirmed_user, login: 'reporter') }

      let(:comment) { create(:comment_project, user: offender) }
      let(:project) { comment.commentable }
      let(:report) { create(:report, reporter: reporter, reportable: comment) }

      let!(:reporter_subscription) { create(:event_subscription_decision, user: reporter) }
      let!(:offender_subscription) { create(:event_subscription_decision, user: offender, receiver_role: 'offender') }

      let(:decision) { create(:decision_favored, moderator: admin, reason: 'This is spam for sure.', reports: [report]) }
      let(:event) { Event::FavoredDecision.last }
      let(:mail) { EventMailer.with(subscribers: event.subscribers, event: event).notification_email.deliver_now }

      before do
        login(admin)
        decision
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'is sent to the reporter and offender' do
        expect(mail.to).to contain_exactly(reporter.email, offender.email)
      end

      it 'has a subject' do
        expect(mail.subject).to eq("Favored #{decision.reports.first.reportable&.class&.name} Report")
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include("'#{decision.moderator}' decided to favor the report. This is the reason:")
        expect(mail.body.encoded).to include('This is spam for sure.')
      end

      it 'renders link to the page of the comment' do
        expect(mail.body.encoded).to include("<a href=\"https://build.example.com/project/show/#{project}#comments-list\">#{project}</a>")
      end
    end

    context 'for an event of type Event::AppealCreated' do
      let(:moderator) { create(:admin_user) }
      let(:offender) { create(:confirmed_user, login: 'offender') } # user who wrote the offensive comment
      let(:reporter) { create(:confirmed_user, login: 'reporter') }
      let(:appellant) { create(:confirmed_user, login: 'appellant') }

      let(:comment) { create(:comment_project, user: offender) }
      let(:project) { comment.commentable }
      let(:report) { create(:report, reporter: reporter, reportable: comment) }

      let!(:moderator_subscription) { create(:event_subscription_appeal_created, user: moderator) }

      let(:decision) { create(:decision_favored, moderator: moderator, reason: 'This is spam for sure.', reports: [report]) }
      let(:appeal) { create(:appeal, appellant: appellant, decision: decision, reason: 'I strongly disagree!') }
      let(:event) { Event::AppealCreated.last }
      let(:mail) { EventMailer.with(subscribers: event.subscribers, event: event).notification_email.deliver_now }

      before do
        login(moderator)
        appeal
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'is sent to the moderator' do
        expect(mail.to).to contain_exactly(decision.moderator.email)
      end

      it 'has a subject' do
        expect(mail.subject).to eq("Appeal to #{decision.reports.first.reportable&.class&.name} decision")
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include("'#{appellant}' decided to appeal to the decision '#{decision.reason}'. This is the reason:")
        expect(mail.body.encoded).to include('I strongly disagree!')
      end

      it 'renders link to the page of the comment' do
        expect(mail.body.encoded).to include("<a href=\"https://build.example.com/project/show/#{project}#comments-list\">#{project}</a>")
      end
    end

    context 'for an event of type Event::AppealCreated of a no longer existing reportable object' do
      let(:moderator) { create(:admin_user) }
      let(:offender) { create(:confirmed_user, login: 'offender') } # user who wrote the offensive comment
      let(:reporter) { create(:confirmed_user, login: 'reporter') }
      let(:appellant) { create(:confirmed_user, login: 'appellant') }

      let(:comment) { create(:comment_project, user: offender) }
      let(:project) { comment.commentable }
      let(:report) { create(:report, reporter: reporter, reportable: comment) }

      let!(:moderator_subscription) { create(:event_subscription_appeal_created, user: moderator) }

      let(:decision) { create(:decision_favored, moderator: moderator, reason: 'This is spam for sure.', reports: [report]) }
      let(:appeal) { create(:appeal, appellant: appellant, decision: decision, reason: 'I strongly disagree!') }
      let(:event) { Event::AppealCreated.last }
      let(:mail) { EventMailer.with(subscribers: event.subscribers, event: event).notification_email.deliver_now }

      before do
        login(moderator)
        comment.destroy!
        appeal
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'is sent to the moderator' do
        expect(mail.to).to contain_exactly(decision.moderator.email)
      end

      it 'has a subject' do
        expect(mail.subject).to eq("Appeal to #{decision.reports.first.reportable&.class&.name} decision")
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include("'#{appellant}' decided to appeal to the decision '#{decision.reason}'. This is the reason:")
        expect(mail.body.encoded).to include('I strongly disagree!')
      end

      it 'renders the text about the missing reported comment' do
        expect(mail.body.encoded).to include("The reported #{decision.reports.first.reportable&.class&.name&.downcase} does not exist anymore.")
      end
    end

    context 'for an event of type Event::AddedUserToGroup' do
      let(:who) { create(:confirmed_user) }
      let(:user) { create(:confirmed_user) }
      let(:group) { create(:group) }
      let!(:subscription) { create(:event_subscription_added_user_to_group, user: user) }

      let(:mail) { EventMailer.with(subscribers: Event::AddedUserToGroup.last.subscribers, event: Event::AddedUserToGroup.last).notification_email.deliver_now }

      before do
        login(user)
        Event::AddedUserToGroup.create!(who: who.login, member: user.login, group: group.title)
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'sends an email to the subscribed user' do
        expect(mail.to).to include(user.email)
      end

      it 'contains the correct subject' do
        expect(mail.subject).to include("'#{who}' added you to the group '#{group}'")
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include("You got added to group '#{group}'")
      end
    end

    context 'for an event of type Event::RemovedUserFromGroup' do
      let(:who) { create(:confirmed_user) }
      let(:user) { create(:confirmed_user) }
      let(:group) { create(:group_with_user, user: user) }
      let!(:subscription) { create(:event_subscription_removed_user_from_group, user: user) }

      let(:mail) { EventMailer.with(subscribers: Event::RemovedUserFromGroup.last.subscribers, event: Event::RemovedUserFromGroup.last).notification_email.deliver_now }

      before do
        login(user)
        Event::RemovedUserFromGroup.create!(who: who.login, member: user.login, group: group.title)
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'sends an email to the subscribed user' do
        expect(mail.to).to include(user.email)
      end

      it 'contains the correct subject' do
        expect(mail.subject).to include("'#{who}' removed you from the group '#{group}'")
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include("You got removed from group '#{group}'")
      end
    end

    context 'for an event of type Event::AssignmentCreate' do
      let(:who) { create(:confirmed_user) }
      let(:user) { create(:confirmed_user) }
      let(:project) { create(:project, name: 'foo') }
      let(:package) { create(:package, name: 'bar', project: project) }
      let!(:subscription) { create(:event_subscription_assignment, user: user) }

      let(:mail) { EventMailer.with(subscribers: Event::AssignmentCreate.last.subscribers, event: Event::AssignmentCreate.last).notification_email.deliver_now }

      before do
        login(user)
        Event::AssignmentCreate.create!(assignee: user.login, who: who.login, project: project.name, package: package.name)
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'sends an email to the subscribed user' do
        expect(mail.to).to include(user.email)
      end

      it 'contains the correct subject' do
        expect(mail.subject).to include("#{user} assigned to the package #{project}/#{package}")
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include("#{who} assigned you")
      end
    end

    context 'for an event of type Event::AssignmentDelete' do
      let(:who) { create(:confirmed_user) }
      let(:user) { create(:confirmed_user) }
      let(:project) { create(:project, name: 'foo') }
      let(:package) { create(:package, name: 'bar', project: project) }
      let!(:subscription) { create(:event_subscription_assignment, user: user) }

      let(:mail) { EventMailer.with(subscribers: Event::AssignmentDelete.last.subscribers, event: Event::AssignmentDelete.last).notification_email.deliver_now }

      before do
        login(user)
        Event::AssignmentDelete.create!(assignee: user.login, who: who.login, project: project.name, package: package.name)
      end

      it 'gets delivered' do
        expect(ActionMailer::Base.deliveries).to include(mail)
      end

      it 'sends an email to the subscribed user' do
        expect(mail.to).to include(user.email)
      end

      it 'contains the correct subject' do
        expect(mail.subject).to include("#{user} unassigned from the package #{project}/#{package}")
      end

      it 'contains the correct text' do
        expect(mail.body.encoded).to include("#{who} unassigned you")
      end
    end
  end
end
