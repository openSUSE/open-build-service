require 'rails_helper'

RSpec.describe Cloud::Backend::UploadJob, type: :model, vcr: true do
  describe '.create' do
    let(:user) { create(:confirmed_user, login: 'tom', ec2_configuration: create(:ec2_configuration)) }
    let(:params) do
      {
        project:    'Cloud',
        package:    'aws',
        repository: 'standard',
        arch:       'x86_64',
        filename:   'appliance.raw.gz',
        region:     'us-east-1'
      }
    end
    let(:response) do
      <<-HEREDOC
      <clouduploadjob name="6">
        <state>created</state>
        <details>waiting to receive image</details>
        <created>1513604055</created>
        <user>mlschroe</user>
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

    context 'with a valid backend response' do
      before do
        allow(Backend::Api::Cloud).to receive(:upload).with(user, params).and_return(response)
      end

      subject { Cloud::Backend::UploadJob.create(user, params) }

      it { expect(subject.valid?).to be_truthy }
      it { expect(subject.id).to eq('6') }
      it { expect(subject.state).to eq('created') }
      it { expect(subject.details).to eq('waiting to receive image') }
      it { expect(subject.user).to eq('mlschroe') }
      it { expect(subject.platform).to eq('ec2') }
      it { expect(subject.project).to eq('Base:System') }
      it { expect(subject.package).to eq('rpm') }
      it { expect(subject.repository).to eq('openSUSE_Factory') }
      it { expect(subject.architecture).to eq('x86_64') }
      it { expect(subject.filename).to eq('rpm-4.14.0-504.2.x86_64.rpm') }
      it { expect(subject.size).to eq('1690860') }
    end

    context 'with an invalid backend response' do
      subject { Cloud::Backend::UploadJob.create(user, params) }

      it { expect(subject.valid?).to be_falsy }
      it 'has the correct error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('no cloud upload server configurated')
      end
    end

    context 'with Timeout::Error' do
      before do
        allow(Backend::Api::Cloud).to receive(:upload).with(user, params).and_raise(Timeout::Error, 'boom')
      end
      subject { Cloud::Backend::UploadJob.create(user, params) }

      it { expect(subject.valid?).to be_falsy }
      it 'has the correct error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('boom')
      end
    end
  end
end
