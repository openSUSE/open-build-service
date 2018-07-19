require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ObsFactory::OpenqaJob do
  describe '.openqa_base_url' do
    it { expect(ObsFactory::OpenqaJob.openqa_base_url).to eq('http://openqa.opensuse.org') }

    context 'with a configured base_url' do
      before do
        stub_const('CONFIG', CONFIG.merge('openqa_base_url' => 'http://configured-url.com'))
      end

      it { expect(ObsFactory::OpenqaJob.openqa_base_url).to eq('http://configured-url.com') }
    end
  end

  describe '.openqa_links_url' do
    it { expect(ObsFactory::OpenqaJob.openqa_links_url).to eq('https://openqa.opensuse.org') }

    context 'with a configured links_url' do
      before do
        stub_const('CONFIG', CONFIG.merge('openqa_links_url' => 'http://links-url.com'))
      end

      it { expect(ObsFactory::OpenqaJob.openqa_links_url).to eq('http://links-url.com') }
    end
  end

  describe '#result_or_state' do
    subject { ObsFactory::OpenqaJob.new(result: 'some-result', state: 'some-state') }

    it { expect(subject.result_or_state).to eq('some-result') }

    context 'with a result value of "none"' do
      subject { ObsFactory::OpenqaJob.new(result: 'none', state: 'some-state') }

      it { expect(subject.result_or_state).to eq('some-state') }
    end
  end

  describe '#failing_modules' do
    let(:modules) do
      %w[passed softfailed running none failed].map do |result|
        { 'name' => "mod_#{result}", 'result' => result }
      end
    end

    subject { ObsFactory::OpenqaJob.new(modules: modules) }

    it 'returns the failed module' do
      expect(subject.failing_modules).to contain_exactly('mod_failed')
    end
  end

  describe '.find_all_by' do
    let(:openqa_base_url) { 'http://openqa.opensuse.org/api/v1/jobs' }
    let(:default_filter) { { scope: 'current' } }
    let(:args) { {} }
    let(:opt) { {} }

    3.times do |n|
      let("job#{n}") { { 'id' => n.to_s, 'name' => "job#{n}", 'iso' => "iso#{n}", 'state' => "state#{n}", 'build' => "build#{n}" } }
    end

    subject { ObsFactory::OpenqaJob.find_all_by(args, opt) }

    before do
      stub_request(:get, "#{openqa_base_url}?#{filters.to_query}").and_return(body: json_response.to_json, status: 200)
    end

    context 'without filters' do
      let(:filters) { default_filter }
      let(:json_response) { { jobs: [job0, job1, job2] } }

      it { expect(subject.map(&:name)).to contain_exactly('job0', 'job1', 'job2') }

      context 'and the result is cached' do
        before do
          Rails.cache.write('openqa_isos', ['iso2'])
          Rails.cache.write('openqa_jobs_for_iso_iso2', [job2])
        end

        it { expect(subject.map(&:name)).to contain_exactly('job2') }

        context 'and refresh option given' do
          let(:opt) { { cache: 'refresh' } }

          it { expect(subject.map(&:name)).to contain_exactly('job0', 'job1', 'job2') }
        end
      end

      context 'with exclude_mod activated' do
        let(:opt) { { exclude_modules: true } }

        before do
          subject
        end

        ['iso0', 'iso1', 'iso2'].each do |iso|
          it { expect(Rails.cache.read("openqa_jobs_for_iso_#{iso}")).to be_nil }
        end

        it { expect(Rails.cache.read('openqa_isos')).to be_nil }
      end

      context 'and without cached isos' do
        before do
          Rails.cache.write('openqa_isos', ['iso2'])
          Rails.cache.write('openqa_jobs_for_iso_iso2', [job2])
        end

        it { expect(subject.map(&:name)).to contain_exactly('job2') }
      end
    end

    context 'with iso filter' do
      let(:job0b) { { 'id' => '4', 'name' => 'job0b', 'iso' => 'iso0', 'state' => 'state1b', 'build' => 'build1b' } }
      let(:args) { { iso: 'iso0' } }
      let(:filters) { default_filter.merge(args) }
      let(:json_response) { { jobs: [job0, job0b] } }

      it { expect(subject.map(&:name)).to contain_exactly('job0', 'job0b') }

      context 'and the result is cached' do
        before do
          Rails.cache.write('openqa_jobs_for_iso_iso0', [job0b])
        end

        it { expect(subject.map(&:name)).to contain_exactly('job0b') }

        context 'and refresh option given' do
          let(:opt) { { cache: 'refresh' } }

          it { expect(subject.map(&:name)).to contain_exactly('job0', 'job0b') }
        end
      end

      context 'with exclude_mod activated' do
        let(:opt) { { exclude_modules: true } }

        before do
          subject
        end

        it { expect(Rails.cache.read('openqa_jobs_for_iso_iso0')).to be_nil }
      end
    end

    context 'with some filters different from iso' do
      let(:args) { { state: 'state2', build: 'build2' } }
      let(:filters) { default_filter.merge(args) }
      let(:json_response) { { jobs: [job1] } }

      it { expect(subject.map(&:name)).to contain_exactly('job1') }
    end

    context 'with no jobs matching' do
      let(:args) { { state: 'non-existent-state' } }
      let(:filters) { default_filter.merge(args) }
      let(:json_response) { {} }

      it { expect(subject).to eq({}) }
    end
  end
end
