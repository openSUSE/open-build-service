# rubocop:disable RSpec/DescribeClass
RSpec.describe 'rpmlint_description' do
  # rubocop:enable RSpec/DescribeClass
  include_context 'rake'

  let(:repo) { 'rpm-software-management/rpmlint' }
  let(:base_path) { 'rpmlint/descriptions' }
  let(:output_path) { Rails.public_path.join('rpmlint/descriptions.yaml') }
  let(:octokit_client) { instance_double(Octokit::Client) }
  let(:task) { 'rpmlint:sync_description' }
  # rubocop:disable RSpec/VerifiedDoubles
  let(:file_one) do
    double('Octokit::Content',
           type: 'file',
           path: "#{base_path}/doc.toml",
           name: 'doc.toml')
  end

  let(:file_two) do
    double('Octokit::Contents',
           type: 'file',
           path: "#{base_path}/perms.toml",
           name: 'perms.toml')
  end

  let(:res_one) { double('Octokit::Contents', content: Base64.encode64('no-doc = "No documentation found."')) }
  let(:res_two) { double('Octokit::Contents', content: Base64.encode64('bad-perm = "Wrong permissions."')) }
  # rubocop:enable RSpec/VerifiedDoubles

  before do
    FileUtils.rm_f(output_path)
    allow(Octokit::Client).to receive(:new).and_return(octokit_client)
  end

  describe 'sync_description' do
    before do
      allow(octokit_client).to receive(:contents)
        .with(repo, path: base_path)
        .and_return([file_one, file_two])

      allow(octokit_client).to receive(:contents)
        .with(repo, path: file_one.path)
        .and_return(res_one)

      allow(octokit_client).to receive(:contents)
        .with(repo, path: file_two.path)
        .and_return(res_two)

      rake_task.invoke
    end

    it 'successfully fetches files and merges them into a YAML file' do
      saved_data = YAML.load_file(output_path)

      expect(saved_data).to include(
        'no-doc' => 'No documentation found.',
        'bad-perm' => 'Wrong permissions.'
      )
    end
  end
end
