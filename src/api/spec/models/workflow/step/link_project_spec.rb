# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Workflow::Step::LinkProject do
  let(:project) { create(:project) }
  let!(:target_project) { create(:project, name: 'openSUSE:Factory') }
  let(:workflow_run) { create(:workflow_run) }
  let(:token) { create(:workflow_token, executor: create(:confirmed_user)) }
  let(:instructions) { { project: project.name, target_project: 'openSUSE:Factory' } }
  let(:step) { described_class.new(workflow_run: workflow_run, token: token, step_instructions: instructions) }

  it 'sets the project link' do
    step.call
    expect(project.reload.linking_to.first.linked_db_project).to eq(target_project)
  end
end
