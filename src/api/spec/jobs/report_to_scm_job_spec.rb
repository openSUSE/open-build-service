require 'rails_helper'

RSpec.describe ReportToScmJob, vcr: false do
  let!(:user) { create(:confirmed_user, login: 'foolano') }
  let!(:token) { Token::Workflow.create(user: user) }
  let!(:project) { create(:project, name: 'project_1', maintainer: user) }
  let!(:package) { create(:package, name: 'package_1', project: project) }
  let!(:repository) { create(:repository, name: 'repository_1', project: project) }
  let!(:event) { Event::BuildSuccess.create({ project: project.name, package: package.name, repository: repository.name, reason: 'foo' }) }
  let(:event_subscription) { EventSubscription.create!(token: token, user: user, package: package, receiver_role: 'reader', payload: 'foo', eventtype: 'Event::BuildSuccess') }

  describe '#perform' do
    before do
      event_subscription
    end

    it { expect(event.undone_jobs).to be_positive }

    subject { described_class.perform_now(event.id) }

    it { expect(subject).to be_truthy }
    it { expect(event.reload.undone_jobs).to be_zero }
  end
end
