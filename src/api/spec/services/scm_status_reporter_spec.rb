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

    context 'status failed on github' do
      let(:event_payload) { { project: 'home:john_doe', package: 'hello', repository: 'openSUSE_Tumbleweed', arch: 'i586' } }
      let(:event_subscription_payload) { { scm: 'github' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('failure') }
    end

    context 'status failed on gitlab' do
      let(:event_payload) { { project: 'home:jane_doe', package: 'bye', repository: 'openSUSE_Leap', arch: 'x86_64' } }
      let(:event_subscription_payload) { { scm: 'gitlab' } }
      let(:token) { 'XYCABC' }
      let(:event_type) { 'Event::BuildFail' }

      subject { scm_status_reporter }

      it { expect(subject.state).to eq('failed') }
    end
  end
end
