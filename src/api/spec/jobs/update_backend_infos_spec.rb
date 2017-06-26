require 'rails_helper'

RSpec.describe UpdateBackendInfos, vcr: true do
  let(:project) { create(:project_with_package, name: 'FakeProject', package_name: 'FakePackage') }
  let(:package) { project.packages.first }
  let(:user) { create(:admin_user, login: 'myself') }
  let(:event) do
    Event::UndeletePackage.new('project' => project.name, 'package' => package.name,
                               'sender' => user.login, 'comment' => 'fake_payload_comment')
  end
  let(:event_without_package) do
    Event::UndeletePackage.new('project' => project.name, 'package' => nil,
                               'sender' => user.login, 'comment' => 'fake_payload_comment')
  end

  context "properly set" do
    let(:other_package) { create(:package, name: 'OtherFakePackage') }

    before do
      allow_any_instance_of(Package).to receive(:update_backendinfo)
      BackendPackage.create(package: other_package, links_to: package)
    end

    subject { UpdateBackendInfos.new(event) }

    after do
      Delayed::Job.enqueue subject
    end

    it { is_expected.to receive(:update_package) }
    it { is_expected.to receive(:after) }
    it { is_expected.not_to receive(:error) }
  end

  context "without a package properly set" do
    before do
      allow(subject).to receive(:update_package)
    end

    subject { UpdateBackendInfos.new(event_without_package) }

    after do
      Delayed::Job.enqueue subject
    end

    it { expect(subject.perform).to be_nil }
    it { is_expected.not_to receive(:update_package) }
  end

  context "when perform raises an exception" do
    before do
      allow(Package).to receive(:find_by_project_and_name).and_raise('FakeExceptionMessage')
      allow($stdout).to receive(:write) # Needed to avoid the puts of the error method
    end

    subject { UpdateBackendInfos.new(event) }

    it 'runs #error' do
      is_expected.to receive(:error)
      expect { Delayed::Job.enqueue subject }.to raise_error('FakeExceptionMessage')
    end
  end
end
