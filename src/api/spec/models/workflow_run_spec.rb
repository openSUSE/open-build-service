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

    context 'when the token has previous auth failures' do
      let(:options) { { api_endpoint: 'https://api.github.com' } }

      before { workflow_run.token.update!(consecutive_auth_failures: 3) }

      it 'resets consecutive_auth_failures to zero' do
        expect { subject }
          .to change { workflow_run.token.reload.consecutive_auth_failures }.from(3).to(0)
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

      it 'does not disable the token of the token workflow' do
        expect { subject }.not_to(change { workflow_run.token.reload.enabled })
      end
    end

    context 'when the SCM responds with a forbidden message' do
      let(:forbidden_failure) do
        -> { workflow_run.save_scm_report_failure('Failed to report back to GitHub: Request is forbidden.', { api_endpoint: 'https://api.github.com' }) }
      end

      it 'increments consecutive_auth_failures on each failure' do
        forbidden_failure.call
        expect(workflow_run.token.reload.consecutive_auth_failures).to eq(1)
      end

      it 'does not disable the token before reaching the failure threshold' do
        (Token::Workflow::AUTH_FAILURE_THRESHOLD - 1).times { forbidden_failure.call }
        expect(workflow_run.token.reload.enabled).to be(true)
      end

      it 'disables the token after reaching the failure threshold' do
        Token::Workflow::AUTH_FAILURE_THRESHOLD.times { forbidden_failure.call }
        expect(workflow_run.token.reload.enabled).to be(false)
      end
    end

  end

  describe '#labeled_pull_request?' do
    context 'when event is pull request opened' do
      let(:workflow_run) { create(:workflow_run) }

      it { expect(workflow_run).not_to be_labeled_pull_request }
    end

    context 'when event is pull request labeled' do
      let!(:workflow_run) { create(:workflow_run, :pull_request_labeled) }

      it { expect(workflow_run).to be_labeled_pull_request }
    end
  end

  describe '#unlabeled_pull_request?' do
    context 'when event is pull request labeled' do
      let(:workflow_run) { create(:workflow_run) }

      it { expect(workflow_run).not_to be_unlabeled_pull_request }
    end

    context 'when event is pull request unlabeled' do
      let!(:workflow_run) { create(:workflow_run, :pull_request_unlabeled) }

      it { expect(workflow_run).to be_unlabeled_pull_request }
    end
  end
end
