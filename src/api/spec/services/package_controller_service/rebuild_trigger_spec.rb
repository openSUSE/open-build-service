require 'rails_helper'

RSpec.describe PackageControllerService::RebuildTrigger do
  let(:project) { OpenStruct.new(name: 'bar') }
  let(:package) { OpenStruct.new(name: 'foo', project: project) }
  let(:params) { {} }
  let(:rebuild_trigger) { described_class.new(package_object: package, package_name_with_multibuild_suffix: package.name, project: project, params: params) }

  it { expect(rebuild_trigger.policy_object).to eq(package) }

  it { expect(rebuild_trigger.success_message).to eq("Triggered rebuild for #{project.name}/#{package.name} successfully.") }

  context 'with error' do
    let(:error_message) do
      "Error while triggering rebuild for #{project.name}/#{package.name}: bar and baz."
    end

    before do
      # rubocop:disable RSpec/MessageChain
      allow(package).to receive_message_chain('errors.full_messages.to_sentence') { 'bar and baz' }
      # rubocop:enable RSpec/MessageChain
    end

    it { expect(rebuild_trigger.error_message).to eq(error_message) }
  end
end
