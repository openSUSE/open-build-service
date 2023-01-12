require 'rails_helper'

RSpec.describe NotificationActionDescriptionComponent, type: :component do
  context 'when the notification is for a Event::RequestStatechange event with a request having only a target' do
    let(:target_project) { create(:project, name: 'project_123') }
    let(:target_package) { create(:package, project: target_project, name: 'package_123') }
    let(:bs_request) { create(:set_bugowner_request, target_project: target_project, target_package: target_package) }
    let(:notification) { create(:notification, :request_state_change, notifiable: bs_request) }

    before do
      render_inline(described_class.new(notification))
    end

    it 'renders a div containing only the target project and package names' do
      expect(rendered_content).to have_selector('div.smart-overflow', text: 'project_123 / package_123')
    end
  end

  context 'when the notification is for a Event::RequestStatechange event with a request having multiple actions' do
    let(:target_project) { create(:project, name: 'project_12345') }
    let(:target_package) { create(:package, project: target_project, name: 'package_12345') }
    let(:bs_request) { create(:set_bugowner_request, target_project: target_project, target_package: target_package) }
    let(:notification) { create(:notification, :request_state_change, notifiable: bs_request) }

    before do
      bs_request.bs_request_actions << create(:bs_request_action_add_maintainer_role)

      render_inline(described_class.new(notification))
    end

    it 'renders a div containing only the target project' do
      expect(rendered_content).to have_selector('div.smart-overflow', exact_text: 'project_12345')
    end
  end

  context 'when the notification is for a Event::RequestCreate event with a request having a source and target' do
    let(:source_project) { create(:project, name: 'source_project_123') }
    let(:source_package) { create(:package, project: source_project, name: 'source_package_123') }
    let(:target_project) { create(:project, name: 'project_123') }
    let(:target_package) { create(:package, project: target_project, name: 'package_123') }
    let(:bs_request) do
      create(:bs_request_with_submit_action, source_project: source_project, source_package: source_package, target_project: target_project, target_package: target_package)
    end
    let(:notification) { create(:notification, :request_created, notifiable: bs_request) }

    before do
      render_inline(described_class.new(notification))
    end

    it 'renders a div containing the source and target project/package names' do
      expect(rendered_content).to have_selector('div.smart-overflow', text: 'source_project_123 / source_package_123project_123 / package_123')
    end
  end

  context 'when the notification is for a Event::ReviewWanted event having only a target' do
    let(:target_project) { create(:project, name: 'project_123') }
    let(:target_package) { create(:package, project: target_project, name: 'package_123') }
    let(:bs_request) { create(:set_bugowner_request, target_project: target_project, target_package: target_package) }
    let(:notification) { create(:notification, :review_wanted, notifiable: bs_request) }

    before do
      render_inline(described_class.new(notification))
    end

    it 'renders a div containing only the target project and package names' do
      expect(rendered_content).to have_selector('div.smart-overflow', text: 'project_123 / package_123')
    end
  end

  context 'when the notification is for a Event::CommentForRequest event' do
    let(:target_project) { create(:project, name: 'project_123') }
    let(:target_package) { create(:package, project: target_project, name: 'package_123') }
    let(:bs_request) { create(:set_bugowner_request, target_project: target_project, target_package: target_package) }
    let(:comment) { create(:comment, commentable: bs_request) }
    let(:notification) { create(:notification, :comment_for_request, notifiable: comment) }

    before do
      render_inline(described_class.new(notification))
    end

    it 'renders a div containing only the target project and package names' do
      expect(rendered_content).to have_selector('div.smart-overflow', text: 'project_123 / package_123')
    end
  end

  context 'when the notification is for a Event::CommentForProject event' do
    let(:project) { create(:project, name: 'my_project') }
    let(:comment) { create(:comment, commentable: project) }
    let(:notification) { create(:notification, :comment_for_project, notifiable: comment) }

    before do
      render_inline(described_class.new(notification))
    end

    it 'renders a div containing the project name' do
      expect(rendered_content).to have_selector('div.smart-overflow', text: 'my_project')
    end
  end

  context 'when the notification is for a Event::CommentForPackage event' do
    let(:project) { create(:project, name: 'my_project_2') }
    let(:package) { create(:package, project: project, name: 'my_package_2') }
    let(:comment) { create(:comment, commentable: package) }
    let(:notification) { create(:notification, :comment_for_package, notifiable: comment) }

    before do
      render_inline(described_class.new(notification))
    end

    it 'renders a div containing the project and package names' do
      expect(rendered_content).to have_selector('div.smart-overflow', text: 'my_project_2 / my_package_2')
    end
  end

  context 'when the notification is for a Event::RelationshipCreate' do
    context 'with the recipient being a user' do
      let(:project) { create(:project, name: 'some_awesome_project') }
      let(:notification) do
        create(:notification, :relationship_create_for_project, notifiable: project, originator: 'Jane', role: 'maintainer')
      end

      before do
        render_inline(described_class.new(notification))
      end

      it 'renders a div containing who added the recipient and their new role in the project' do
        expect(rendered_content).to have_selector('div.smart-overflow', text: 'Jane made you maintainer of some_awesome_project')
      end
    end

    context 'with the recipient being a group' do
      let(:project) { create(:project, name: 'some_awesome_project') }
      let(:notification) do
        create(:notification, :relationship_create_for_project, notifiable: project, originator: 'Jane', recipient_group: 'group_1', role: 'maintainer')
      end

      before do
        render_inline(described_class.new(notification))
      end

      it "renders a div containing who added the recipient's group and their new role in the project" do
        expect(rendered_content).to have_selector('div.smart-overflow', text: 'Jane made group_1 maintainer of some_awesome_project')
      end
    end
  end

  context 'when the notification is for a Event::RelationshipDelete' do
    context 'with the recipient being a user' do
      let(:project) { create(:project, name: 'some_awesome_project') }
      let(:notification) do
        create(:notification, :relationship_delete_for_project, notifiable: project, originator: 'Jane', role: 'maintainer')
      end

      before do
        render_inline(described_class.new(notification))
      end

      it "renders a div containing who removed the recipient's role in the project" do
        expect(rendered_content).to have_selector('div.smart-overflow', text: 'Jane removed you as maintainer of some_awesome_project')
      end
    end

    context 'with the recipient being a group' do
      let(:project) { create(:project, name: 'some_awesome_project') }
      let(:notification) do
        create(:notification, :relationship_delete_for_project, notifiable: project, originator: 'Jane', recipient_group: 'group_1', role: 'maintainer')
      end

      before do
        render_inline(described_class.new(notification))
      end

      it "renders a div containing who removed the recipient's group role in the project" do
        expect(rendered_content).to have_selector('div.smart-overflow', text: 'Jane removed group_1 as maintainer of some_awesome_project')
      end
    end
  end
end
