require 'rails_helper'

RSpec.describe Workflow, type: :model, vcr: true do
  include_context 'a scm payload hash'

  let(:user) { create(:confirmed_user, :with_home) }
  let!(:token) { create(:workflow_token, user: user) }

  subject do
    described_class.new(workflow_instructions: yaml, scm_webhook: ScmWebhook.new(payload: github_extractor_payload), token: token)
  end

  describe '#call' do
    let(:yaml) { { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] } }

    context 'PR was reopened' do
      let(:github_extractor_payload) do
        {
          scm: 'github',
          action: 'reopened',
          event: 'pull_request',
          pr_number: 4
        }
      end

      before { allow(Project).to receive(:restore) }

      it 'restores a project' do
        subject.call
        expect(Project).to have_received(:restore)
      end
    end

    context 'PR was closed' do
      let(:github_extractor_payload) do
        {
          scm: 'github',
          action: 'closed',
          event: 'pull_request',
          pr_number: 4
        }
      end
      let!(:target_project) { create(:project, name: "home:#{user.login}:test-project:PR-4") }

      it 'removes the target project' do
        expect { subject.call }.to change(Project, :count).from(2).to(1)
      end
    end
  end

  describe '#steps' do
    let(:yaml) do
      { 'steps' => [{ 'branch_package' => { 'source_project' => 'test-project', 'source_package' => 'test-package' } }] }
    end

    context 'with a supported step' do
      it 'initializes the supported step objects' do
        expect(subject.steps.first).to be_a(Workflow::Step::BranchPackageStep)
      end
    end

    context 'with several supported steps' do
      let(:yaml) do
        { 'steps' => [{ 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } },
                      { 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } }] }
      end

      it 'returns an array with two items' do
        expect(subject.steps.count).to be 2
      end
    end

    context 'with one unsupported step' do
      let(:yaml) do
        { 'steps' => [{ 'unsupported_step' => {} },
                      { 'branch_package' => { source_project: 'project',
                                              source_package: 'package' } }] }
      end

      it 'returns an array with only one item' do
        expect(subject.steps.count).to be 1
      end
    end

    context 'with no steps specified' do
      let(:yaml) do
        {}
      end

      it 'returns an empty array' do
        expect(subject.steps).to be_empty
      end
    end
  end

  describe '#filters' do
    ['architectures', 'repositories'].each do |filter|
      context "with #{filter} filters having valid values" do
        let(:yaml) do
          {
            'filters' => {
              filter => { 'only' => ['s390x', 12.3, 567], 'ignore' => ['i586'] }
            }
          }
        end

        it "returns #{filter} filters with 'only' having precedence over 'ignore'" do
          expect(subject.filters).to eq({ "#{filter}": { only: ['s390x', 12.3, 567] } })
        end
      end
    end

    context 'without filters' do
      let(:yaml) do
        {}
      end

      it 'returns nothing' do
        expect(subject.filters).to eq({})
      end
    end
  end
end
