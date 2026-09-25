class TestScmsyncUrl
  include ScmsyncUrl

  attr_accessor :scmsync

  def initialize(scmsync: nil)
    @scmsync = scmsync
  end
end

RSpec.describe ScmsyncUrl do
  describe '#scmsync_url' do
    subject(:scmsync_url) { record.scmsync_url }

    let(:record) { TestScmsyncUrl.new(scmsync: scm_url) }
    let(:commit_sha) { '1234567890abcdef1234567890abcdef12345678' }

    context 'with a github branch' do
      let(:scm_url) { 'https://github.com/example/repo.git#main' }

      it { expect(scmsync_url).to eq('https://github.com/example/repo/tree/main') }
    end

    context 'with a github subdirectory' do
      let(:scm_url) { 'https://github.com/example/repo.git?subdir=packages/test#main' }

      it { expect(scmsync_url).to eq('https://github.com/example/repo/tree/main/packages/test') }
    end

    context 'with a gitlab commit' do
      let(:scm_url) { "https://gitlab.com/example/repo.git##{commit_sha}" }

      it { expect(scmsync_url).to eq("https://gitlab.com/example/repo/-/commit/#{commit_sha}") }
    end

    context 'with a gitea subdirectory' do
      let(:scm_url) { "https://src.opensuse.org/home:autogits_obs_staging_bot/autogits:XObsPrj:PR:3.git?subdir=test-dir##{commit_sha}" }

      it { expect(scmsync_url).to eq("https://src.opensuse.org/home:autogits_obs_staging_bot/autogits:XObsPrj:PR:3/src/commit/#{commit_sha}/test-dir") }
    end

    context 'with an unknown provider' do
      let(:scm_url) { 'https://example.com/example/repo.git?subdir=test-dir#main' }

      it { expect(scmsync_url).to eq('https://example.com/example/repo#main') }
    end

    context 'with an invalid URL' do
      let(:scm_url) { 'not a valid url' }

      it { expect(scmsync_url).to eq('not a valid url') }
    end
  end

  describe 'including model classes' do
    it { expect(Package.new).to respond_to(:scmsync_url) }
    it { expect(Project.new).to respond_to(:scmsync_url) }
  end
end
