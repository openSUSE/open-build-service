RSpec.describe WorkflowRun, :vcr do
  describe '#save_scm_report_success' do
    subject { workflow_run.save_scm_report_success(options) }

    let(:workflow_run) { create(:workflow_run) }

    context 'when providing a permitted key' do
      let(:options) { { api_endpoint: 'https://api.github.com' } }

      it { expect { subject }.to change(SCMStatusReport, :count).by(1) }

      it 'stores the correct parameters in request_parameters' do
        subject
        expect(JSON.parse(SCMStatusReport.last.request_parameters)).to include('api_endpoint' => 'https://api.github.com')
      end

      it 'stores correct status value' do
        subject
        expect(SCMStatusReport.last.status).to eq('success')
      end
    end

    context 'when providing some other keys' do
      let(:options) { { non_permitted_key: 'some value' } }

      it { expect { subject }.to change(SCMStatusReport, :count).by(1) }

      it 'stores empty request_parameters' do
        subject
        expect(JSON.parse(SCMStatusReport.last.request_parameters)).to be_empty
      end

      it 'stores correct status value' do
        subject
        expect(SCMStatusReport.last.status).to eq('success')
      end
    end
  end

  describe '#save_scm_report_failure' do
    subject { workflow_run.save_scm_report_failure('oops it failed', options) }

    let(:workflow_run) { create(:workflow_run) }

    context 'when providing a permitted key' do
      let(:options) { { api_endpoint: 'https://api.github.com' } }

      it { expect { subject }.to change(SCMStatusReport, :count).by(1) }

      it 'stores the correct parameters in request_parameters' do
        subject
        expect(JSON.parse(SCMStatusReport.last.request_parameters)).to include('api_endpoint' => 'https://api.github.com')
      end

      it 'stores correct values for failure' do
        subject
        expect(SCMStatusReport.last.response_body).to eql('oops it failed')
        expect(SCMStatusReport.last.status).to eq('fail')
      end

      it 'marks the workflow run as failed' do
        subject
        expect(workflow_run.reload.status).to eql('fail')
      end

      it { expect { subject }.to change(Event::WorkflowRunFail, :count).by(1) }
    end

    context 'when providing some other keys' do
      let(:options) { { non_permitted_key: 'some value' } }

      it { expect { subject }.to change(SCMStatusReport, :count).by(1) }

      it 'stores empty request_parameters' do
        subject
        expect(JSON.parse(SCMStatusReport.last.request_parameters)).to be_empty
      end

      it 'stores correct values for failure' do
        subject
        expect(SCMStatusReport.last.response_body).to eql('oops it failed')
        expect(SCMStatusReport.last.status).to eq('fail')
      end

      it 'marks the workflow run as failed' do
        subject
        expect(workflow_run.reload.status).to eql('fail')
      end
    end
  end
end
