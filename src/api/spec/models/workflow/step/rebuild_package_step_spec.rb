require 'rails_helper'

RSpec.describe Workflow::Step::RebuildPackage, vcr: true do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }
  let(:project) { create(:project, name: 'openSUSE:Factory', maintainer: user) }
  let(:package) { create(:package, name: 'hello_world', project: project) }

  let!(:repository) { create(:repository, project: project, rebuild: 'direct', name: 'repository_1', architectures: ['x86_64']) }

  let(:step_instructions) { { package: package.name, project: project.name } }

  let(:scm_webhook) do
    SCMWebhook.new(payload: {
                     scm: 'github',
                     event: 'pull_request',
                     action: 'opened',
                     pr_number: 1,
                     source_repository_full_name: 'reponame',
                     commit_sha: '123'
                   })
  end

  subject do
    described_class.new(step_instructions: step_instructions,
                        scm_webhook: scm_webhook,
                        token: token)
  end

  before do
    project.store
  end

  it { expect { subject.call }.not_to raise_error }

  context 'user has no permission to trigger rebuild' do
    let(:another_user) { create(:confirmed_user, :with_home, login: 'Oggy') }
    let!(:token) { create(:workflow_token, executor: another_user) }

    it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError) }
  end

  describe '#validate_project_and_package_name' do
    context 'when the project is invalid' do
      let(:step_instructions) { { package: package.name, project: 'Invalid/format' } }

      it 'gives an error for invalid name' do
        subject.valid?

        expect { subject.call }.not_to change(Package, :count)
        expect(subject.errors.full_messages.to_sentence).to eq("invalid project 'Invalid/format'")
      end
    end

    context 'when the package is invalid' do
      let(:step_instructions) { { package: 'Invalid/format', project: project.name } }

      it 'gives an error for invalid name' do
        subject.valid?

        expect { subject.call }.not_to change(Package, :count)
        expect(subject.errors.full_messages.to_sentence).to eq("invalid package 'Invalid/format'")
      end
    end
  end
end
