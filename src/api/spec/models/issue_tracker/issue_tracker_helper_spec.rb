require 'rails_helper'

RSpec.describe IssueTracker::IssueTrackerHelper do
  context 'cve' do
    let(:issue) { IssueTracker::IssueTrackerHelper.new('CVE-2010-31337') }

    describe '.new method' do
      it { expect(issue).not_to be_nil }
    end

    describe '#tracker' do
      it { expect(issue.tracker).to eq('cve') }
    end
  end

  context 'other tracker' do
    let(:issue) { IssueTracker::IssueTrackerHelper.new('bnc#31337') }

    describe '.new method' do
      it { expect(issue).not_to be_nil }
    end

    describe '#tracker' do
      it { expect(issue.tracker).to eq('bnc') }
    end
  end
end
