require 'webmock/rspec'

RSpec.describe BsRequestAction::Differ::ForSource, :vcr do
  subject do
    BsRequestAction::Differ::ForSource.new(
      bs_request_action: bs_request_action,
      source_package_names: [source_package.name],
      options: options
    )
  end

  let(:user) { create(:confirmed_user, login: 'moi') }
  let(:source_project) { create(:project, name: 'source_project', maintainer: user) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:target_package) { create(:package, name: 'target_package', project: target_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           source_package: source_package,
           target_package: target_package,
           source_rev: 2)
  end
  let(:bs_request_action) { bs_request.bs_request_actions.first }
  let(:xml_response) do
    <<-RESPONSE
    <sourcediff key="caaa0df4ce0789d73c0f5abcf1947efd">
      <old project="home:Admin:branches:world" package="ruby" rev="2" srcmd5="676a0937d734bc49d76604a47ef66574" />
      <new project="home:Admin:branches:world" package="ruby" rev="3" srcmd5="be0f48bb6b62911bd437ba7888e02af5" />
      <files>
        <file state="changed">
          <old name="ruby.spec" md5="76ae97f7808db6c00e6ef87eb3a4c49c" size="20" />
          <new name="ruby.spec" md5="70781f21decb618ec0056838e9989e6b" size="39" />
          <diff lines="5">@@ -1,1 +1,1 @@
    -foo
     No newline at end of file
    +bar
     No newline at end of file
          </diff>
        </file>
      </files>
      <issues>
      </issues>
    </sourcediff>
    RESPONSE
  end
  let(:options) { { filelimit: 42, tarlimit: 43, withissues: 1, view: :xml } }

  describe '#perform' do
    context 'with not accepted requests' do
      let(:params) do
        {
          cmd: 'diff',
          rev: 2,
          oproject: target_project.name,
          opackage: target_package.name,
          filelimit: 42, # options
          tarlimit: 43, # options
          expand: 1,
          view: :xml,
          withissues: 1
        }
      end
      let(:path) { "#{CONFIG['source_url']}/source/#{source_project}/#{source_package}?#{params.to_param}" }

      before do
        stub_request(:post, path).and_return(body: xml_response)
      end

      it { expect(subject.perform).to eq(xml_response) }
    end

    context 'with error' do
      let(:path) { "#{CONFIG['source_url']}/source/#{source_project}/#{source_package}" }
      let(:no_such_revision) { '<status code="404"><summary>no such revision</summary><details>404 no such revision</details></status>' }

      before do
        stub_request(:post, path).with(query: hash_including('cmd' => 'diff', 'opackage' => target_package.name)).and_return(body: no_such_revision, status: 404)
      end

      it { expect { subject.perform }.to raise_error(BsRequestAction::Errors::DiffError, %r{The diff call for source_project/source_package failed: no such revision}) }
    end

    context 'with superseded request' do
      let(:superseded_bs_request) do
        create(:bs_request_with_submit_action,
               source_package: source_package,
               target_package: target_package,
               source_rev: 8)
      end
      let!(:superseded_bs_request_action) { superseded_bs_request.bs_request_actions.first }
      let(:params) do
        {
          cmd: 'diff',
          filelimit: options[:filelimit],
          tarlimit: options[:tarlimit],
          rev: bs_request_action.source_rev,
          orev: superseded_bs_request_action.source_rev,
          view: :xml,
          withissues: 1
        }
      end
      let(:path) { "#{CONFIG['source_url']}/source/#{source_project}/#{source_package}?#{params.to_param}" }

      before do
        options[:superseded_bs_request_action] = superseded_bs_request_action
        stub_request(:post, path).and_return(body: xml_response)
      end

      it { expect(subject.perform).to eq(xml_response) }
    end

    context 'with accepted requests' do
      let(:params) do
        {
          cmd: 'diff',
          rev: '2',
          orev: '3',
          filelimit: 10_000, # default
          tarlimit: 10_000 # default
        }
      end
      let!(:bs_request_action_accept_info) do
        create(:bs_request_action_accept_info,
               bs_request_action: bs_request_action,
               srcmd5: 2,
               osrcmd5: 3)
      end
      let(:path) { "#{CONFIG['source_url']}/source/#{target_project}/#{target_package}?#{params.to_param}" }

      before do
        stub_request(:post, path).and_return(body: xml_response)
      end

      context 'returns one request' do
        subject do
          BsRequestAction::Differ::ForSource.new(
            bs_request_action: bs_request_action,
            source_package_names: [source_package.name]
          )
        end

        it { expect(subject.perform).to eq(xml_response) }
      end

      context 'returns more than one' do
        subject do
          BsRequestAction::Differ::ForSource.new(
            bs_request_action: bs_request_action,
            source_package_names: [source_package.name, source_package.name]
          )
        end

        it { expect(subject.perform).to eq(xml_response * 2) }
      end
    end
  end
end
