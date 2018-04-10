# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Cloud::UploadJob, type: :model, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom', ec2_configuration: create(:ec2_configuration)) }
  let(:params) do
    {
      project:    'Cloud',
      package:    'aws',
      repository: 'standard',
      arch:       'x86_64',
      filename:   'appliance.raw.xz',
      region:     'us-east-1',
      ami_name:   'my-image',
      user:       user,
      target:     'ec2'
    }
  end
  let(:response) do
    <<-HEREDOC
    <clouduploadjob name="6">
      <state>created</state>
      <details>waiting to receive image</details>
      <created>1513604055</created>
      <user>#{user.login}</user>
      <target>ec2</target>
      <project>Base:System</project>
      <repository>openSUSE_Factory</repository>
      <package>rpm</package>
      <arch>x86_64</arch>
      <filename>rpm-4.14.0-504.2.x86_64.rpm</filename>
      <size>1690860</size>
    </clouduploadjob>
    HEREDOC
  end

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:arch).in_array(['x86_64']) }
    it { is_expected.to validate_inclusion_of(:target).in_array(['ec2']) }
    it { is_expected.to validate_presence_of :user }
    it { is_expected.to allow_value('foo.raw.xz').for(:filename) }
    it { is_expected.to allow_value('foo.vhdfixed.xz').for(:filename) }
    it { is_expected.not_to allow_value('foo.rpm').for(:filename) }
    it { is_expected.not_to allow_value('foo.vhdfixed').for(:filename) }
    it { is_expected.not_to allow_value('foo.raw').for(:filename) }
    it { is_expected.to allow_value('subnet-23sdfg54').for(:vpc_subnet_id) }
    it { is_expected.not_to allow_value('subnet-2$sdfg54').for(:vpc_subnet_id) }
  end

  describe '.create' do
    context 'with a valid backend response' do
      before do
        allow(Backend::Api::Cloud).to receive(:upload).with(params).and_return(response)
      end

      subject { Cloud::UploadJob.create(params) }

      it { expect(subject.valid?).to be_truthy }
    end

    context 'with an invalid Backend::UploadJob' do
      subject { Cloud::UploadJob.create(params) }

      it { expect(subject.valid?).to be_falsy }
      it 'has the correct error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to match(/no cloud upload server configurated/)
      end
    end

    context 'with an invalid User::UploadJob' do
      let!(:job) { create(:upload_job, job_id: 6) }
      before do
        allow(Backend::Api::Cloud).to receive(:upload).with(params).and_return(response)
      end

      subject { Cloud::UploadJob.create(params) }

      it { expect(subject.valid?).to be_falsy }
      it 'has the correct error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to match(/already been taken/)
      end
    end
  end
end
