require 'rails_helper'

RSpec.describe WorkflowRun, vcr: true do
  let(:workflow_run) { create(:workflow_run) }

  describe '#save_scm_report_success' do
    subject { workflow_run.save_scm_report_success(options) }

    context 'when providing a permitted key' do
      let(:options) { { api_endpoint: 'https://api.github.com' } }

      it { expect { subject }.to change(ScmStatusReport, :count).by(1) }
      it { expect(JSON.parse(subject.request_parameters)).to include('api_endpoint' => 'https://api.github.com') }
    end

    context 'when providing some other keys' do
      let(:options) { { non_permitted_key: 'some value' } }

      it { expect { subject }.to change(ScmStatusReport, :count).by(1) }
      it { expect(JSON.parse(subject.request_parameters)).to be_empty }
    end
  end

  describe '#save_scm_report_failure' do
    subject { workflow_run.save_scm_report_failure('oops it failed', options) }

    context 'when providing a permitted key' do
      let(:options) { { api_endpoint: 'https://api.github.com' } }

      it { expect { subject }.to change(ScmStatusReport, :count).by(1) }
      it { expect(JSON.parse(subject.request_parameters)).to include('api_endpoint' => 'https://api.github.com') }
      it { expect(subject.response_body).to eql('oops it failed') }

      it 'marks the workflow run as failed' do
        subject
        expect(workflow_run.reload.status).to eql('fail')
      end
    end

    context 'when providing some other keys' do
      let(:options) { { non_permitted_key: 'some value' } }

      it { expect { subject }.to change(ScmStatusReport, :count).by(1) }
      it { expect(JSON.parse(subject.request_parameters)).to be_empty }
      it { expect(subject.response_body).to eql('oops it failed') }

      it 'marks the workflow run as failed' do
        subject
        expect(workflow_run.reload.status).to eql('fail')
      end
    end
  end
end
