require 'rails_helper'

RSpec.describe ChannelBinary, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tux') }
  let(:project) { create(:project, name: 'projectX') }
  let(:repository) { create(:repository, architectures: ['i586'], project: project) }
  let(:package) { create(:package, project: project, name: 'zaz') }
  let(:channel) { create(:channel, package: package) }
  let(:channel_binary_list) { create(:channel_binary_list, channel: channel, repository: repository, project: project, architecture: repository.architectures.first) }

  before do
    login user
  end

  describe '.find_by_project_and_package' do
    let!(:channel_binary) do
      create(:channel_binary, name: 'foo', project: project, architecture: repository.architectures.first,
                              repository: repository, channel_binary_list: channel_binary_list, package: package.name)
    end
    let!(:maintenance_project) { create(:maintenance_project, target_project: project) }

    it { expect(ChannelBinary.find_by_project_and_package(project.name, package.name)).not_to be_empty }
    it { expect(ChannelBinary.find_by_project_and_package(project.name, package.name)).to include(channel_binary) }
  end

  describe '#create_channel_package_into' do
    let!(:channel_binary) do
      create(:channel_binary, name: 'bar', project: project, architecture: repository.architectures.first,
                              repository: repository, channel_binary_list: channel_binary_list, package: package.name)
    end

    it { expect(channel_binary.create_channel_package_into(project, 'foo')).not_to be_nil }
    it { expect(channel_binary.create_channel_package_into(project, 'foo')).to be_a(Package) }
  end
end
