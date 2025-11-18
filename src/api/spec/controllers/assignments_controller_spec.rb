RSpec.describe AssignmentsController do
  before { Flipper.enable(:foster_collaboration, admin) }

  describe '#create' do
    subject do
      post(:create, body: create_assignment_xml, params: { project_name: project.name, package_name: package.name }, format: :xml)
    end

    let(:admin) { create(:admin_user) }
    let(:package) { create(:package_with_maintainer) }
    let(:project) { package.project }
    let(:create_assignment_xml) do
      <<~XML
        <assignment><assignee>#{assignee.login}</assignee></assignment>
      XML
    end

    before { login admin }

    context 'when the assigner can assign users' do
      let(:assignee) { package.relationships.first.user }

      it { expect(subject).to have_http_status(:ok) }

      it { expect { subject }.to change(Assignment, :count).from(0).to(1) }
    end

    context 'when the assigner cannot assign users' do
      let(:assignee) { create(:confirmed_user) }

      it { expect(subject).to have_http_status(:bad_request) }

      it { expect { subject }.not_to(change(Assignment, :count)) }
    end
  end

  describe '#destroy' do
    subject do
      post(:destroy, params: { project_name: project.name, package_name: package.name }, format: :xml)
    end

    let(:admin) { create(:admin_user) }
    let(:package) { create(:package_with_maintainer) }
    let(:project) { package.project }
    let(:assignee) { package.relationships.first.user }
    let!(:assignment) { create(:assignment, assignee: assignee, assigner: admin, package: package) }

    context 'when the assigner remove assignments' do
      before { login admin }

      it { expect(subject).to have_http_status(:ok) }

      it 'destroys the assignment' do
        expect { subject }.to change(Assignment, :count).from(1).to(0)
      end
    end

    context 'when the assigner cannot remove assignments' do
      let(:some_user) { create(:confirmed_user) }

      before { login some_user }

      it { expect(subject).to have_http_status(:forbidden) }

      it 'does not destroy the assignment' do
        expect { subject }.not_to(change(Assignment, :count))
      end
    end
  end
end
