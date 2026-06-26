RSpec.describe BsRequestAction do
  let(:user) { create(:confirmed_user, :with_home, login: 'request_user') }

  before do
    allow(User).to receive(:current).and_return(user)
  end

  context 'encoding of sourcediffs', :vcr do
    let(:file_content) { "-{\xA2:\xFA*\xA3q\u0010\xC2X\\\x9D" }
    let(:utf8_encoded_file_content) { file_content.encode('UTF-8', 'binary', invalid: :replace, undef: :replace) }
    let(:project) { user.home_project }
    let(:target_package) do
      create(:package_with_file, name: 'package_encoding_1',
                                 file_content: file_content, project: project)
    end
    let(:source_package) do
      create(:package_with_file, name: 'package_encoding_2',
                                 file_content: 'test', project: project)
    end
    let(:bs_request) { create(:bs_request_with_submit_action, creator: user, target_package: target_package, source_package: source_package) }
    let(:bs_request_action) { bs_request.bs_request_actions.first }

    it { expect(bs_request_action.sourcediff.valid_encoding?).to be(true) }
    it { expect(bs_request_action.sourcediff).to include(utf8_encoded_file_content) }
  end

  context 'uniqueness validation of type' do
    let(:source_prj) { create(:project) }
    let(:source_pkg) { create(:package, project: source_prj) }
    let(:target_prj) { create(:project) }
    let(:target_pkg) { create(:package, project: target_prj) }
    let(:action_attributes) do
      {
        type: 'submit',
        source_package: source_pkg,
        source_project: source_prj,
        target_project: target_prj,
        target_package: target_pkg
      }
    end

    let(:bs_request) { create(:bs_request, action_attributes.merge(creator: user)) }
    let(:bs_request_action) { bs_request.bs_request_actions.first }

    it { expect(bs_request_action).to be_valid }

    it 'validates uniqueness for same type' do
      bs_request.bs_request_actions << bs_request.bs_request_actions.first.dup
      expect { bs_request.send(:check_uniq_actions!) }.to raise_error(BsRequest::Errors::ConflictingActions)
    end

    it 'does not validate uniqueness for different types' do
      bs_request.bs_request_actions << build(:bs_request_action_add_bugowner_role)
      expect { bs_request.send(:check_uniq_actions!) }.not_to raise_error
    end
  end

  it { is_expected.to belong_to(:bs_request).touch(true).optional }

  describe '.set_source_and_target_associations' do
    let(:project) { create(:project_with_package, name: 'Apache', package_name: 'apache2') }
    let(:package) { project.packages.first }

    it 'sets target_package_object to package if target_package and target_project parameters provided' do
      action = BsRequestAction.create(target_project: project.name, target_package: package)
      expect(action.target_package_object).to eq(package)
    end

    it 'sets target_project_object to project if target_project parameters provided' do
      action = BsRequestAction.create(target_project: project)
      expect(action.target_project_object).to eq(project)
    end
  end

  describe '#find_action_with_same_target' do
    let(:target_package) { create(:package) }
    let(:target_project) { target_package.project }
    let(:source_package) { create(:package) }
    let(:source_project) { source_package.project }
    let(:bs_request) do
      create(:bs_request_with_submit_action,
             source_package: source_package,
             target_package: target_package, creator: user)
    end
    let(:bs_request_action) { bs_request.bs_request_actions.first }

    context 'with a non existing bs request' do
      it { expect(bs_request_action.find_action_with_same_target(nil)).to be_nil }
    end

    context 'with no matching action' do
      let(:another_bs_request) { build(:bs_request, creator: user) }

      it { expect(bs_request_action.find_action_with_same_target(another_bs_request)).to be_nil }
    end

    context 'with matching action' do
      let!(:another_bs_request) do
        create(:bs_request_with_submit_action,
               source_package: source_package,
               target_package: target_package, creator: user)
      end
      let(:another_bs_request_action) { another_bs_request.bs_request_actions.first }

      it { expect(bs_request_action.find_action_with_same_target(another_bs_request)).to eq(another_bs_request_action) }

      context 'with more than one action' do
        let(:another_target_package) { create(:package) }
        let(:another_target_project) { another_target_package.project }
        let(:another_bs_request) do
          create(:bs_request_with_submit_action,
                 source_package: source_package,
                 target_package: another_target_package, creator: user)
        end
        let(:another_bs_request_action) do
          create(:bs_request_action_submit,
                 bs_request: another_bs_request,
                 source_package: source_package.name,
                 source_project: source_project.name,
                 target_project: target_project.name,
                 target_package: target_package.name)
        end

        before do
          another_bs_request.bs_request_actions << another_bs_request_action
        end

        it { expect(bs_request_action.find_action_with_same_target(another_bs_request)).to eq(another_bs_request_action) }
      end
    end
  end

  describe '#target_maintainer?' do
    context 'without target' do
      let(:action_without_target) { build(:bs_request_action) }

      it 'is false' do
        expect(action_without_target).not_to be_target_maintainer(user)
      end

      it 'works on nil' do
        expect(action_without_target).not_to be_target_maintainer(nil)
      end
    end

    context 'on home target' do
      let(:another_user) { create(:confirmed_user) }
      let(:bs_request) do
        create(:set_bugowner_request, target_project: user.home_project, creator: user)
      end
      let(:bs_request_action) { bs_request.bs_request_actions.first }

      it 'is true for user' do
        expect(bs_request_action).to be_target_maintainer(user)
      end

      it 'works on nil' do
        expect(bs_request_action).not_to be_target_maintainer(nil)
      end

      it 'is false for another user' do
        expect(bs_request_action).not_to be_target_maintainer(another_user)
      end
    end
  end

  describe '#check_maintenance_release' do
    before do
      allow(User).to receive(:session!).and_return(user)
    end

    let(:binary_list) do
      <<-XML
        <binarylist>
          <binary filename="_buildenv" size="16724" mtime="1559026680" />
        </binarylist>
      XML
    end

    let(:build_history) do
      <<-XML
        <buildhistory>
          <entry rev="1" srcmd5="ef521827053c2e3b3cc735662c5d5bb0" versrel="2.10-1" bcnt="1" time="1559026681" duration="59" />
        </buildhistory>
      XML
    end

    let(:source_prj) { create(:project, name: 'super_source_pkg') }
    let(:source_pkg) { create(:package, project: source_prj, name: 'super_source_pkg') }
    let(:target_prj) { create(:project) }
    let(:target_pkg) { create(:package, project: target_prj) }
    let(:action_attributes) do
      {
        type: 'submit',
        source_package: source_pkg,
        source_project: source_prj,
        target_project: target_prj,
        target_package: target_pkg
      }
    end

    let(:repository) { create(:repository, name: 'super_repo', architectures: ['x86_64'], project: source_prj) }
    let(:architecture) { Architecture.find_by!(name: 'x86_64') }
    let!(:bs_request) { create(:bs_request, action_attributes.merge(creator: user)) }
    let(:bs_request_action) { bs_request.bs_request_actions.first }

    context 'everything works as expected' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive_messages(files: binary_list, history: build_history)
        allow(Directory).to receive(:hashed).and_return('srcmd5' => 'ef521827053c2e3b3cc735662c5d5bb0')
      end

      it { expect { bs_request_action.check_maintenance_release(source_pkg, repository, architecture) }.not_to raise_error }
    end

    context 'patchinfo is not build' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:files).and_return("<binarylist></binarylist>\n")
      end

      it { expect { bs_request_action.check_maintenance_release(source_pkg, repository, architecture) }.to raise_error(BsRequestAction::Errors::BuildNotFinished) }
    end

    context 'last patchinfo is not build', :vcr do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive_messages(files: binary_list, history: build_history)
      end

      it { expect { bs_request_action.check_maintenance_release(source_pkg, repository, architecture) }.to raise_error(BsRequestAction::Errors::BuildNotFinished) }
    end
  end

  describe 'create_expand_package' do
    before do
      allow(User).to receive(:session!).and_return(user)
      allow(Backend::Api::BuildResults::Binaries).to receive_messages(files: binary_list, history: build_history)
      allow(Directory).to receive(:hashed).and_return(hashed)
    end

    let(:hashed) do
      {
        'linkinfo' => { 'project' => target_prj.name, 'package' => target_pkg.name,
                        'srcmd5' => 'aaee591c4043f45e369dd8b022ce1a7b',
                        'xsrcmd5' => 'ab6a14a292165f7f9eb012fc9528224a',
                        'lsrcmd5' => '683e6f3cee9a19e1e839dcc61cbc6256' },
        'srcmd5' => 'ef521827053c2e3b3cc735662c5d5bb0'
      }
    end

    let(:binary_list) do
      <<-XML
        <binarylist>
          <binary filename="_buildenv" size="16724" mtime="1559026680" />
        </binarylist>
      XML
    end

    let(:build_history) do
      <<-XML
        <buildhistory>
          <entry rev="1" srcmd5="ef521827053c2e3b3cc735662c5d5bb0" versrel="2.10-1" bcnt="1" time="1559026681" duration="59" />
        </buildhistory>
      XML
    end

    let(:source_prj) { create(:project, name: 'super_source_pkg') }
    let(:source_pkg) { create(:package, project: source_prj, name: 'super_source_pkg') }
    let(:target_prj) { create(:project, name: 'super_target_prj') }
    let(:target_pkg) { create(:package, project: target_prj, name: 'super_target_prj') }
    let(:action_attributes) do
      {
        type: 'submit',
        source_package: source_pkg,
        source_project: source_prj,
        target_project: target_prj,
        target_package: target_pkg
      }
    end

    let(:repository) { create(:repository, name: 'super_repo', architectures: ['x86_64'], project: source_prj) }
    let(:architecture) { Architecture.find_by!(name: 'x86_64') }
    let!(:bs_request) { create(:bs_request, action_attributes.merge(creator: user)) }
    let(:bs_request_action) { bs_request.bs_request_actions.first }

    context 'Raise RemoteSource' do
      it { expect { bs_request_action.create_expand_package(['foo']) }.to raise_error(BsRequestAction::RemoteSource) }
    end

    context 'Everything should work', :vcr do
      it { expect { bs_request_action.create_expand_package([source_pkg]) }.not_to raise_error }
    end

    context 'Should return an array', :vcr do
      it { expect(bs_request_action.create_expand_package([source_pkg])).to be_an(Array) }
    end
  end

  describe 'check_expand_errors', :vcr do
    let(:project) { user.home_project }
    let(:attrib) { create(:enforce_revisions_in_requests_attrib, project: project) }

    let(:target_package) do
      create(:package_with_file, name: 'tpackage', file_content: 'Hallo', project: project)
    end
    let(:source_package) do
      create(:package_with_file, name: 'spackage', file_content: 'Trick', project: project)
    end
    let(:bs_request) { create(:bs_request_with_submit_action, creator: user, target_package: target_package, source_package: source_package) }
    let(:bs_request_action) { bs_request.bs_request_actions.first }

    context 'RevisionEnforcing enabled' do
      before do
        attrib
      end

      it 'adds revision' do
        # trigger the code (from within the request is the easiest trigger point)
        bs_request.sanitize!
        expect(bs_request_action.source_rev).not_to be_nil
      end

      context 'with _link in submitted source' do
        let!(:hacker_package) do
          create(:package_with_file, name: 'hpackage', file_content: 'Evil Content', file_name: '0wnyou.txt', project: project)
        end
        let(:source_package) do
          link_content = "<link package='hpackage'/>"
          create(:package_with_file, name: 'spackage', file_name: '_link', file_content: link_content, project: project)
        end
        let(:bs_request) { create(:bs_request_with_submit_action, creator: user, target_package: target_package, source_package: source_package, source_rev: '2') }

        # make sure we do not trust the submitted source revision for longer than the creation time
        it 'freezes revision' do
          bs_request.sanitize!
          expect(bs_request_action.source_rev.length).to eq(32)
        end

        context 'with updatelink' do
          let(:bs_request) { create(:bs_request_with_submit_action, creator: user, target_package: target_package, source_package: source_package, updatelink: true) }

          it 'throws exception' do
            expect { bs_request.sanitize! }.to raise_error do |exception|
              expect(exception.message.to_s).to match('updatelink option')
            end
          end
        end
      end
    end

    context 'Without RevisionEnforcing' do
      it "doesn't add revision" do
        bs_request.sanitize!
        expect(bs_request_action.source_rev).to be_nil
      end
    end
  end

  describe '#check_for_expand_errors' do
    let(:project) { user.home_project }
    let(:target_package) do
      create(:package_with_file, name: 'package_encoding_1', project: project)
    end
    let(:source_package) do
      create(:package_with_file, name: 'package_encoding_2', project: project)
    end
    let(:bs_request) { create(:bs_request_with_submit_action, creator: user, target_package: target_package, source_package: source_package) }
    let(:bs_request_action) { bs_request.bs_request_actions.first }

    context 'when there is a problem with the backend' do
      let(:mocked_backend) { class_double(Backend::Api::Sources::Package).as_stubbed_const }

      before do
        allow(mocked_backend).to receive('files').and_raise(Backend::Error, 'Oops!')
      end

      context 'and we have a revision' do
        before { bs_request_action.source_rev = '1234' }

        it 'returns an error message' do
          expect { bs_request_action.send(:check_for_expand_errors!, true) }
            .to raise_error(ExpandError, 'The source of package home:request_user/package_encoding_2 for revision 1234 is broken')
        end
      end

      context 'but we do not have a revision' do
        it 'also returns an error message' do
          expect { bs_request_action.send(:check_for_expand_errors!, true) }
            .to raise_error(ExpandError, 'The source of package home:request_user/package_encoding_2 is broken')
        end
      end
    end
  end

  describe '#toggle_seen_by' do
    subject do
      bs_request_action.toggle_seen_by(user)
      bs_request_action.seen_by_users
    end

    let(:bs_request) { create(:bs_request_with_submit_action, creator: user) }
    let(:bs_request_action) { bs_request.bs_request_actions.first }

    context 'mark the action as seen by the user' do
      it 'adds the user to the seen_by_users association' do
        expect(subject).to include(user)
      end
    end

    context 'mark the action as not seen by the user' do
      before do
        # prepare the data with the association
        bs_request_action.seen_by_users << user
      end

      it 'removes the user from the seen_by_users association' do
        expect(subject).not_to include(user)
      end
    end

    context 'mark the action as seen by a nil user' do
      before do
        bs_request_action.toggle_seen_by(nil)
      end

      it { expect(bs_request_action.seen_by_users).not_to include(user) }
    end
  end
end
