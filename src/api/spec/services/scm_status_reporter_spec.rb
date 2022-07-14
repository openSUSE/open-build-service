require 'rails_helper'

RSpec.describe SCMStatusReporter, type: :service do
  let(:scm_status_reporter) { SCMStatusReporter.new(event_payload, event_subscription_payload, token, event_type) }

  describe '.new' do
    context 'status pending when event_type is missing' do
      let(:event_payload) { {} }
      let(:event_subscription_payload) { {} }
      let(:token) { 'XYCABC' }
      let(:event_type) { nil }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('pending') }
    end
  end
end
