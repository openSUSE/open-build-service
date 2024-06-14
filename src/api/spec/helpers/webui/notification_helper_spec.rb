RSpec.describe Webui::NotificationHelper do
  describe '#mark_as_read_or_unread_button' do
    let(:link) { mark_as_read_or_unread_button(notification) }

    context 'for unread notification' do
      let(:notification) { create(:web_notification, delivered: false) }

      it { expect(link).to include(my_notifications_path(notification_ids: [notification.id])) }
      it { expect(link).to include('state=unread') }
      it { expect(link).to include('Mark as read') }
      it { expect(link).to include('fa-check fas') }
    end

    context 'for read notification' do
      let(:notification) { create(:web_notification, delivered: true) }

      it { expect(link).to include(my_notifications_path(notification_ids: [notification.id])) }
      it { expect(link).to include('state=read') }
      it { expect(link).to include('Mark as unread') }
      it { expect(link).to include('fa-undo fas') }
    end
  end

  describe '#excerpt' do
    let(:user) { create(:user) }

    context 'notification for a BsRequest without a description' do
      let(:request) { create(:bs_request_with_submit_action, description: nil) }
      let(:notification) { create(:web_notification, :request_created, notifiable: request, subscriber: user) }

      it do
        expect(excerpt(notification)).to have_text('')
      end
    end

    context 'notification for a short comment' do
      let(:comment) { create(:comment_project, body: 'Nice project!') }
      let(:notification) { create(:web_notification, :comment_for_project, notifiable: comment, subscriber: user) }

      it do
        expect(excerpt(notification)).to have_text('Nice project!')
      end
    end

    context 'notification for a long description' do
      let(:report) { create(:report, reason: Faker::Lorem.characters(number: 120)) }
      let(:notification) { create(:web_notification, :create_report, notifiable: report, subscriber: user) }

      it do
        expect(excerpt(notification)).to have_text('...')
      end
    end
  end

  describe '#description' do
    subject { description(notification) }

    context 'when the notification is for a Event::RequestStatechange event with a request having only a target' do
      let(:target_project) { create(:project, name: 'project_123') }
      let(:target_package) { create(:package, project: target_project, name: 'package_123') }
      let(:request) { create(:set_bugowner_request, target_project: target_project, target_package: target_package) }
      let(:notification) { create(:notification, :request_state_change, notifiable: request) }

      it 'renders a div containing only the target project and package names' do
        expect(subject).to have_text('project_123 / package_123')
      end
    end

    context 'when the notification is for a Event::RequestStatechange event with a request having multiple actions' do
      let(:target_project) { create(:project, name: 'project_12345') }
      let(:target_package) { create(:package, project: target_project, name: 'package_12345') }
      let(:request) { create(:set_bugowner_request, target_project: target_project, target_package: target_package) }
      let(:notification) { create(:notification, :request_state_change, notifiable: request) }

      before do
        request.bs_request_actions << create(:bs_request_action_add_maintainer_role)
      end

      it 'renders a div containing only the target project' do
        expect(subject).to have_text('project_12345')
      end
    end

    context 'when the notification is for a Event::RequestCreate event with a request having a source and target' do
      let(:source_project) { create(:project, name: 'source_project_123') }
      let(:source_package) { create(:package, project: source_project, name: 'source_package_123') }
      let(:target_project) { create(:project, name: 'project_123') }
      let(:target_package) { create(:package, project: target_project, name: 'package_123') }
      let(:request) do
        create(:bs_request_with_submit_action, source_project: source_project, source_package: source_package, target_project: target_project, target_package: target_package)
      end
      let(:notification) { create(:notification, :request_created, notifiable: request) }

      it 'renders a div containing the source and target project/package names' do
        expect(subject).to have_text('source_project_123 / source_package_123project_123 / package_123')
      end
    end

    context 'when the notification is for a Event::ReviewWanted event having only a target' do
      let(:target_project) { create(:project, name: 'project_123') }
      let(:target_package) { create(:package, project: target_project, name: 'package_123') }
      let(:request) { create(:set_bugowner_request, target_project: target_project, target_package: target_package) }
      let(:notification) { create(:notification, :review_wanted, notifiable: request) }

      it 'renders a div containing only the target project and package names' do
        expect(subject).to have_text('project_123 / package_123')
      end
    end

    context 'when the notification is for a Event::CommentForRequest event' do
      let(:target_project) { create(:project, name: 'project_123') }
      let(:target_package) { create(:package, project: target_project, name: 'package_123') }
      let(:request) { create(:set_bugowner_request, target_project: target_project, target_package: target_package) }
      let(:comment) { create(:comment, commentable: request) }
      let(:notification) { create(:notification, :comment_for_request, notifiable: comment) }

      it 'renders a div containing only the target project and package names' do
        expect(subject).to have_text('project_123 / package_123')
      end
    end

    context 'when the notification is for a Event::CommentForProject event' do
      let(:project) { create(:project, name: 'my_project') }
      let(:comment) { create(:comment, commentable: project) }
      let(:notification) { create(:notification, :comment_for_project, notifiable: comment) }

      it 'renders a div containing the project name' do
        expect(subject).to have_text('my_project')
      end
    end

    context 'when the notification is for a Event::CommentForPackage event' do
      let(:project) { create(:project, name: 'my_project_2') }
      let(:package) { create(:package, project: project, name: 'my_package_2') }
      let(:comment) { create(:comment, commentable: package) }
      let(:notification) { create(:notification, :comment_for_package, notifiable: comment) }

      it 'renders a div containing the project and package names' do
        expect(subject).to have_text('my_project_2 / my_package_2')
      end
    end

    context 'when the notification is for a Event::RelationshipCreate' do
      context 'with the recipient being a user' do
        let(:project) { create(:project, name: 'some_awesome_project') }
        let(:notification) do
          create(:notification, :relationship_create_for_project, notifiable: project, originator: 'Jane', role: 'maintainer')
        end

        it 'renders a div containing who added the recipient and their new role in the project' do
          expect(subject).to have_text('Jane made you maintainer of some_awesome_project')
        end
      end

      context 'with the recipient being a group' do
        let(:project) { create(:project, name: 'some_awesome_project') }
        let(:notification) do
          create(:notification, :relationship_create_for_project, notifiable: project, originator: 'Jane', recipient_group: 'group_1', role: 'maintainer')
        end

        it "renders a div containing who added the recipient's group and their new role in the project" do
          expect(subject).to have_text('Jane made group_1 maintainer of some_awesome_project')
        end
      end

      context 'when the notification is for a Event::RelationshipDelete' do
        context 'with the recipient being a user' do
          let(:project) { create(:project, name: 'some_awesome_project') }
          let(:notification) do
            create(:notification, :relationship_delete_for_project, notifiable: project, originator: 'Jane', role: 'maintainer')
          end

          it "renders a div containing who removed the recipient's role in the project" do
            expect(subject).to have_text('Jane removed you as maintainer of some_awesome_project')
          end
        end

        context 'with the recipient being a group' do
          let(:project) { create(:project, name: 'some_awesome_project') }
          let(:notification) do
            create(:notification, :relationship_delete_for_project, notifiable: project, originator: 'Jane', recipient_group: 'group_1', role: 'maintainer')
          end

          it "renders a div containing who removed the recipient's group role in the project" do
            expect(subject).to have_text('Jane removed group_1 as maintainer of some_awesome_project')
          end
        end
      end

      context 'when the notification is for an Event::CreateReport' do
        # TODO: refactor this
        context 'with the recipient being a user' do
          let(:notification) do
            create(:notification, :create_report, originator: 'user_1', reason: 'Because reasons.')
          end

          it 'renders a div containing who created a report and for what' do
            expect(subject).to have_text("'#{notification.notifiable.user.login}' created a report for a comment. This is the reason:")
          end
        end
      end

      context 'when the notification is for an Event::ClearedDecision' do
        let(:notification) do
          create(:notification, :cleared_decision)
        end

        it 'renders the information about the cleared decision' do
          expect(subject).to have_text("'#{notification.notifiable.moderator}' decided to clear the report. This is the reason:")
        end
      end

      context 'when the notification is for an Event::FavoredDecision' do
        let(:notification) do
          create(:notification, :favored_decision)
        end

        it 'renders the information about the favored decision' do
          expect(subject).to have_text("'#{notification.notifiable.moderator}' decided to favor the report. This is the reason:")
        end
      end
    end
  end
end
