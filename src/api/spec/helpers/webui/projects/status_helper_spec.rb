require 'rails_helper'

RSpec.describe Webui::Projects::StatusHelper do
  describe '.parse_status' do
    let(:problems) do
      [
        'different_changes',
        'different_sources',
        'diff_against_link',
        'error-foo',
        'currently_declined',
        'no-existing-error'
      ]
    end

    let(:package) do
      ActiveSupport::HashWithIndifferentAccess.new(
        name: 'baz',
        requests_from: [],
        requests_to: [],
        develpackage: 'bar',
        develproject: 'foo',
        develmtime: 5.days.ago,
        currently_declined: '5',
        upstream_url: 'http://example.org/foo',
        problems: problems
      )
    end

    context 'no error is raised' do
      it { expect { helper.parse_status('foo', package) }.not_to raise_error }
    end

    context 'it returns a hash' do
      subject { helper.parse_status('foo', package) }

      it { expect(subject).to be_a(Hash) }
    end

    context 'returned hash summary' do
      subject { helper.parse_status('foo', package)[:summary] }

      it { expect(subject).to be_an(Array) }
      it { expect(subject).not_to be_empty }
      it { expect(subject.count).to be >= 5 }
    end

    context 'icon when error was the last evaluated error' do
      let(:problems) { ['error-foo'] }

      subject { helper.parse_status('foo', package)[:icon_type] }

      it { expect(subject).to eq('error') }
    end

    context 'icon when ok when there are no problems' do
      let(:problems) { [] }

      subject { helper.parse_status('foo', package)[:icon_type] }

      it { expect(subject).to eq('ok') }
    end

    context 'sortkey when there are no problems' do
      let(:problems) { [] }

      subject { helper.parse_status('foo', package)[:sortkey] }

      it { expect(subject).to eq("9-ok-#{package[:name]}") }
    end

    context 'icon when diff_against_link was the last evaluated error' do
      let(:problems) { ['diff_against_link'] }

      subject { helper.parse_status('foo', package)[:icon_type] }

      it { expect(subject).to eq('changes') }
    end

    context 'icon when currently_declined was the last evaluated error' do
      let(:problems) { ['currently_declined'] }

      subject { helper.parse_status('foo', package)[:icon_type] }

      it { expect(subject).to eq('error') }
    end

    context 'sortkey when currently_declined was the last evaluated error' do
      let(:problems) { ['currently_declined'] }

      subject { helper.parse_status('foo', package)[:sortkey] }

      it { expect(subject).to eq("2-declines-#{package[:name]}") }
    end
  end
end
