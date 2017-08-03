require 'rails_helper'
# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe UpdateBackendInfosJob, vcr: true do
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

  context "when properly set" do
    context "behaves like a CreateJob and runs update_package" do
      subject { UpdateBackendInfosJob.new(event) }

      after do
        Delayed::Job.enqueue subject
      end

      it { is_expected.to receive(:update_package) }
      it { is_expected.to receive(:after) }
      it { is_expected.not_to receive(:error) }
    end

    context "process packages chains" do
      let(:other_package) { create(:package, name: 'OtherFakePackage', project: project) }
      let(:run_the_job) do
        Timecop.travel(Time.now + 30.days) do
          Delayed::Job.enqueue(UpdateBackendInfosJob.new(event))
        end
      end
      let!(:backend_package) { package.backend_package }
      let(:linking_backend_package) { BackendPackage.create(package: other_package, links_to: package) }

      it "it updates the backend info of the package" do
        updated_at_before = backend_package.updated_at
        run_the_job
        expect(updated_at_before).not_to eq(backend_package.reload.updated_at)
      end

      it "it updates the backend info of the linking package" do
        linking_updated_at_before = linking_backend_package.updated_at
        run_the_job
        expect(linking_updated_at_before).not_to eq(linking_backend_package.reload.updated_at)
      end
    end
  end

  context "without a package properly set" do
    before do
      allow(subject).to receive(:update_package)
    end

    subject { UpdateBackendInfosJob.new(event_without_package) }

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

    subject { UpdateBackendInfosJob.new(event) }

    it 'runs #error' do
      is_expected.to receive(:error)
      expect { Delayed::Job.enqueue subject }.to raise_error('FakeExceptionMessage')
    end
  end
end
