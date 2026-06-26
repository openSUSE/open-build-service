RSpec.describe BsRequestAction::Differ::QueryBuilderForSuperseded do
  let(:user) { create(:confirmed_user, login: 'moi') }
  let(:source_project) { create(:project, name: 'source_project', maintainer: user) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:target_project) { create(:project, name: 'target_project') }
  let(:target_package) { create(:package, name: 'target_package', project: target_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           source_package: source_package,
           target_package: target_package)
  end
  let(:bs_request_action) { bs_request.bs_request_actions.first }
  let(:superseded_bs_request) do
    create(:bs_request_with_submit_action,
           source_package: source_package,
           target_package: target_package)
  end
  let(:superseded_bs_request_action) { superseded_bs_request.bs_request_actions.first }
  let(:query_builder) do
    BsRequestAction::Differ::QueryBuilderForSuperseded.new(
      superseded_bs_request_action: superseded_bs_request_action,
      bs_request_action: bs_request_action,
      source_package_name: source_package.name
    )
  end

  describe '#build' do
    subject { query_builder.build }

    context 'for accepted bs_request_actions' do
      subject do
        BsRequestAction::Differ::QueryBuilderForSuperseded.new(
          superseded_bs_request_action: superseded_bs_request_action,
          bs_request_action: bs_request_action,
          source_package_name: source_package.name
        ).build
      end

      before do
        superseded_bs_request_action.update(source_rev: 42)
      end

      context 'with a oxsrcmd5' do
        let!(:accept_info) do
          create(:bs_request_action_accept_info,
                 bs_request_action: bs_request_action,
                 opackage: 'opackage',
                 oproject: 'oproject',
                 xsrcmd5: 'xsrcmd5',
                 oxsrcmd5: 'oxsrcmd5')
        end

        it { expect(subject[:rev]).to eq('oxsrcmd5') }
        it { expect(subject[:orev]).to eq('42') }
        it { expect(subject[:opackage]).to eq(superseded_bs_request_action.source_package) }
        it { expect(subject[:oproject]).to eq(superseded_bs_request_action.source_project) }
        it { expect(subject.keys.length).to eq(4) }
      end

      context 'with an osrcmd5' do
        let!(:accept_info) do
          create(:bs_request_action_accept_info,
                 bs_request_action: bs_request_action,
                 opackage: 'opackage',
                 oproject: 'oproject',
                 srcmd5: 'xrcmd5',
                 osrcmd5: 'osrcmd5')
        end

        it { expect(subject[:rev]).to eq(accept_info.osrcmd5) }
      end

      context 'without an osrcmd5 and oxsrcmd5' do
        let!(:accept_info) do
          create(:bs_request_action_accept_info,
                 bs_request_action: bs_request_action,
                 opackage: 'opackage',
                 oproject: 'oproject')
        end

        it { expect(subject[:rev]).to eq('0') }
      end
    end

    context 'for not accepted bs_request_actions' do
      context 'from the same source' do
        subject do
          BsRequestAction::Differ::QueryBuilderForSuperseded.new(
            superseded_bs_request_action: superseded_bs_request_action,
            bs_request_action: bs_request_action,
            source_package_name: source_package.name
          ).build
        end

        it { expect(subject[:orev]).to eq('0') }
        it { expect(subject[:rev]).to eq('0') }
        it { expect(subject.keys).to contain_exactly(:orev, :rev) }
      end

      context 'from different sources' do
        let!(:another_source_project) { create(:project, name: 'another_source_project', maintainer: user) }
        let!(:another_source_package) { create(:package, name: 'another_source_package', project: another_source_project) }
        let!(:superseded_bs_request) do
          create(:bs_request_with_submit_action,
                 source_package: another_source_package,
                 target_package: target_package)
        end
        let!(:superseded_bs_request_action) { superseded_bs_request.bs_request_actions.first }

        it { expect(subject[:orev]).to eq('0') }
        it { expect(subject[:oproject]).to eq(superseded_bs_request_action.source_project) }
        it { expect(subject[:opackage]).to eq(superseded_bs_request_action.source_package) }
        it { expect(subject[:rev]).to eq('0') }
        it { expect(subject.keys).to contain_exactly(:rev, :orev, :oproject, :opackage) }
      end
    end
  end

  describe '#project_name' do
    subject { query_builder }

    context 'of accepted bs_request_actions' do
      context 'with an oproject' do
        let!(:accept_info) do
          create(:bs_request_action_accept_info,
                 bs_request_action: bs_request_action,
                 opackage: 'opackage',
                 oproject: 'oproject',
                 srcmd5: 'xrcmd5',
                 osrcmd5: 'osrcmd5')
        end

        it { expect(subject.project_name).to eq(accept_info.oproject) }
      end

      context 'without an oproject' do
        let!(:accept_info) do
          create(:bs_request_action_accept_info,
                 bs_request_action: bs_request_action,
                 srcmd5: 'xrcmd5',
                 osrcmd5: 'osrcmd5')
        end

        it { expect(subject.project_name).to eq(bs_request_action.target_project) }
      end
    end

    context 'of not accepted bs_request_actions' do
      it { expect(subject.project_name).to eq(bs_request_action.source_project) }
    end
  end

  describe '#package_name' do
    subject { query_builder }

    context 'of accepted bs_request_actions' do
      context 'with an opackage' do
        let!(:accept_info) do
          create(:bs_request_action_accept_info,
                 bs_request_action: bs_request_action,
                 opackage: 'opackage',
                 oproject: 'oproject',
                 srcmd5: 'xrcmd5',
                 osrcmd5: 'osrcmd5')
        end

        it { expect(subject.package_name).to eq(accept_info.opackage) }
      end

      context 'without an opackage' do
        let!(:accept_info) do
          create(:bs_request_action_accept_info,
                 bs_request_action: bs_request_action,
                 srcmd5: 'xrcmd5',
                 osrcmd5: 'osrcmd5')
        end

        it { expect(subject.package_name).to eq(bs_request_action.target_package) }
      end
    end

    context 'of not accepted bs_request_actions' do
      it { expect(subject.package_name).to eq(bs_request_action.source_package) }
    end
  end
end
