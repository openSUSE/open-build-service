require 'rails_helper'

RSpec.describe Workflow::Step::BranchPackageStep, vcr: true do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }

  subject do
    described_class.new(step_instructions: step_instructions,
                        scm_extractor_payload: scm_extractor_payload,
                        token: create(:workflow_token, user: user))
  end

  describe '#allowed_event_and_action?' do
    let(:step_instructions) { {} }

    context 'when we feed a valid extractor payload for github' do
      let(:scm_extractor_payload) do
        {
          scm: 'github',
          event: 'pull_request',
          action: 'opened'
        }
      end

      it { expect(subject).to be_allowed_event_and_action }
    end

    context 'when we feed a valid extractor payload for gitlab' do
      let(:scm_extractor_payload) do
        {
          scm: 'gitlab',
          event: 'Merge Request Hook',
          action: 'open'
        }
      end

      it { expect(subject).to be_allowed_event_and_action }
    end
  end

  describe '#call' do
    let(:project) { create(:project, name: 'foo_project', maintainer: user) }
    let(:package) { create(:package_with_file, name: 'bar_package', project: project) }

    before do
      project
      package
      login(user)
    end

    context 'when we feed an extractor payload for github' do
      let(:scm_extractor_payload) do
        {
          scm: 'github',
          event: 'pull_request',
          action: 'opened',
          pr_number: 1
        }
      end

      context 'and the payload is valid' do
        let(:step_instructions) do
          {
            source_project: package.project.name,
            source_package: package.name
          }
        end

        it { expect { subject.call }.to(change(Package, :count).by(1)) }
        it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
      end

      context "but we don't provide source_project" do
        let(:step_instructions) do
          {
            source_package: package.name
          }
        end

        it { expect { subject.call }.to(change(Package, :count).by(0)) }
      end

      context "but we don't provide a source_package" do
        let(:step_instructions) do
          {
            source_project: package.project.name
          }
        end

        it { expect { subject.call }.to(change(Package, :count).by(0)) }
      end
    end

    context 'when we feed an extractor payload for gitlab' do
      let(:scm_extractor_payload) do
        {
          scm: 'gitlab',
          event: 'Merge Request Hook',
          action: 'open',
          pr_number: 3
        }
      end

      context 'and the payload is valid' do
        let(:step_instructions) do
          {
            source_project: package.project.name,
            source_package: package.name
          }
        end

        it { expect { subject.call }.to(change(Package, :count).by(1)) }
        it { expect { subject.call.source_file('_branch_request') }.not_to raise_error }
      end

      context "but we don't provide a source_project" do
        let(:step_instructions) do
          {
            source_package: package.name
          }
        end

        it { expect { subject.call }.to(change(Package, :count).by(0)) }
      end

      context "but we don't provide a source_package" do
        let(:step_instructions) do
          {
            source_project: package.project.name
          }
        end

        it { expect { subject.call }.to(change(Package, :count).by(0)) }
      end
    end
  end
end
