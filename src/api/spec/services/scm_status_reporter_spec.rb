require 'rails_helper'

RSpec.describe SCMStatusReporter, type: :service do
  let(:scm_status_reporter) { SCMStatusReporter.new(payload, token, event_type) }

  describe '.new' do
    context 'status pending when event_type is missing' do
      let(:payload) { {} }
      let(:token) { 'XYCABC' }
      let(:event_type) { nil }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('pending') }
    end

    context 'status failed on github' do
      let(:payload) { { scm: 'github' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('failure') }
    end

    context 'status failed on gitlab' do
      let(:payload) { { scm: 'gitlab' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('failed') }
    end
  end
end
