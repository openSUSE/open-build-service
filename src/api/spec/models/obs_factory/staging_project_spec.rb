require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ObsFactory::StagingProject do
  let(:factory) { create(:project, name: 'openSUSE:Factory') }
  let(:factoryppc) { create(:project, name: 'openSUSE:Factory:PowerPC') }
  let!(:staging_a) { create(:project, name: 'openSUSE:Factory:Staging:A') }
  let!(:staging_a_dvd) { create(:project, name: 'openSUSE:Factory:Staging:A:DVD') }
  let!(:staging_b) { create(:project, name: 'openSUSE:Factory:Staging:B') }
  let!(:staging_b_dvd) { create(:project, name: 'openSUSE:Factory:Staging:B:DVD') }
  let!(:staging_c) { create(:project, name: 'openSUSE:Factory:Staging:C') }
  let!(:staging_c_dvd) { create(:project, name: 'openSUSE:Factory:Staging:C:DVD') }
  let(:opensuse_132) { create(:project, name: 'openSUSE:13.2') }
  let!(:opensuse_staging_a) { create(:project, name: 'openSUSE:13.2:Staging:A') }
  let!(:opensuse_staging_b) { create(:project, name: 'openSUSE:13.2:Staging:B') }
  let(:factory_distribution) { ObsFactory::Distribution.find(factory.name) }
  let(:staging_project_a) { ObsFactory::StagingProject.new(project: staging_a, distribution: factory_distribution) }
  let(:staging_project_adi) { ObsFactory::StagingProject.new(project: staging_adi, distribution: factory_distribution) }

  describe '::find' do
    subject { ObsFactory::StagingProject.find(factory_distribution, '42') }

    context 'when there is a matching project' do
      let!(:project) { create(:project, name: 'openSUSE:Factory:Staging:42') }

      it 'returns the staging project' do
        is_expected.to be_kind_of ObsFactory::StagingProject
        expect(subject.name).to eq 'openSUSE:Factory:Staging:42'
        expect(subject.project).to eq project
        expect(subject.distribution).to eq factory_distribution
      end
    end

    context 'when there is no matching project' do
      it { is_expected.to be_nil }
    end
  end

  describe '#adi_staging?' do
    let(:project) { create(:project, name: 'openSUSE:Factory:Staging:adi:42') }

    subject { ObsFactory::StagingProject.new(project: project, distribution: factory_distribution) }

    context "when the project name includes 'Staging:adi'" do
      let(:project) { create(:project, name: 'openSUSE:Factory:Staging:adi:42') }

      it { expect(subject.adi_staging?).to be true }
    end

    context "when the project name does not include 'Staging:adi'" do
      let(:project) { create(:project, name: 'openSUSE:Factory:Staging:42') }

      it { expect(subject.adi_staging?).to be false }
    end
  end

  describe 'self.for' do
    context 'openSUSE:Factory' do
      subject { ObsFactory::StagingProject.for(factory_distribution) }

      it { expect(subject.count).to eq(3) }
    end

    context 'openSUSE:Factory:PowerPC' do
      let(:factoryppc_distribution) { ObsFactory::Distribution.find(factoryppc.name) }
      subject { ObsFactory::StagingProject.for(factoryppc_distribution) }

      it { expect(subject.count).to eq(3) }
    end

    context 'openSUSE:13.2' do
      let(:opensuse_132_distribution) { ObsFactory::Distribution.find(opensuse_132.name) }
      subject { ObsFactory::StagingProject.for(opensuse_132_distribution) }

      it { expect(subject.count).to eq(2) }
    end
  end

  describe '.name' do
    subject { staging_project_a }

    it { expect(subject.name).to eq('openSUSE:Factory:Staging:A') }
  end

  describe '.description' do
    let(:staging_with_description) { create(:project, name: 'openSUSE:Factory:Staging:D', description: 'Fake description') }
    subject { ObsFactory::StagingProject.new(project: staging_with_description, distribution: factory_distribution) }

    it { expect(subject.description).to eq('Fake description') }
  end

  describe '.prefix' do
    context 'with a staging project' do
      subject { staging_project_a }

      it { expect(subject.prefix).to eq('openSUSE:Factory:Staging:') }
    end

    context 'with an adi staging project' do
      let(:staging_adi) { create(:project, name: 'openSUSE:Factory:Staging:adi:15') }
      subject { staging_project_adi }

      it { expect(subject.prefix).to eq('openSUSE:Factory:Staging:adi:') }
    end
  end

  describe '.letter' do
    context 'with a staging project' do
      subject { staging_project_a }

      it { expect(subject.letter).to eq('A') }
    end

    context 'with an ADI staging project' do
      let(:staging_adi) { create(:project, name: 'openSUSE:Factory:Staging:adi:15') }
      subject { staging_project_adi }

      it { expect(subject.letter).to eq('15') }
    end
  end

  describe '.id' do
    context 'with a staging project' do
      subject { staging_project_a }

      it { expect(subject.id).to eq('A') }
    end

    context 'with an ADI staging project' do
      let(:staging_adi) { create(:project, name: 'openSUSE:Factory:Staging:adi:15') }
      subject { staging_project_adi }

      it { expect(subject.id).to eq('adi:15') }
    end
  end

  describe '.obsolete_requests' do
    include_context 'a staging project with description'
    let(:bs_request_1) { create(:bs_request, number: 614_459) }
    let!(:request_1) { ObsFactory::Request.new(bs_request_1) }

    subject { ObsFactory::StagingProject.new(project: staging_h, distribution: factory_distribution) }

    context 'with obsolete requests' do
      let(:target_project) { create(:project, name: 'target_project') }
      let(:source_project) { create(:project, name: 'source_project') }
      let(:target_package) { create(:package, name: 'target_package', project: target_project) }
      let(:source_package) { create(:package, name: 'source_package', project: source_project) }
      let(:bs_request_2) do
        create(:declined_bs_request,
               target_project: target_project.name,
               target_package: target_package.name,
               source_project: source_project.name,
               source_package: source_package.name,
               number: 614_471)
      end
      let!(:request_2) { ObsFactory::Request.new(bs_request_2) }

      it { expect(subject.obsolete_requests).to eq([request_2]) }
    end

    context 'without obsolete requests' do
      let(:bs_request_2) { create(:bs_request, number: 614_471) }
      let!(:request_2) { ObsFactory::Request.new(bs_request_2) }

      it { expect(subject.obsolete_requests).to eq([]) }
    end
  end

  describe '.subproject' do
    context 'with one subproject' do
      subject { staging_project_a }

      it { expect(subject.subproject.class).to eq(ObsFactory::StagingProject) }
      it { expect(subject.subproject.project).to eq(staging_a_dvd) }
    end

    context 'with more than one subproject' do
      let!(:staging_a_iso) { create(:project, name: 'openSUSE:Factory:Staging:A:ISO') }

      subject { staging_project_a }

      it { expect(subject.subproject).to eq(nil) }
      it do
        expect(Rails.logger).to receive(:error).with('There too many subprojects, we can not handle this')
        subject.subproject
      end
    end
  end

  describe '.subprojects' do
    context 'project with subprojects' do
      subject { staging_project_a }

      it { expect(subject.subprojects.first.project).to eq(staging_a_dvd) }
      it { expect(subject.subprojects.count).to eq(1) }
    end

    context 'project without subprojects' do
      subject { ObsFactory::StagingProject.new(project: staging_a_dvd, distribution: factory_distribution) }

      it { expect(subject.subprojects).to eq([nil]) }
    end
  end

  describe '.openqa_jobs' do
    subject { staging_project_a }

    context '@openqa_jobs is nil' do
      context 'openqa results are not relevant' do
        it { expect(subject.openqa_jobs).to eq([]) }
      end

      context 'openqa results are relevant' do
        before do
          allow_any_instance_of(ObsFactory::StagingProject).to receive(:openqa_results_relevant?).and_return(true)
        end

        it { expect(subject.openqa_jobs).to eq({}) }
      end
    end

    context '@openqa_jobs is not nil' do
      before do
        subject.instance_variable_set(:@openqa_jobs, {})
      end

      it { expect(subject.openqa_jobs).to be_empty }
    end
  end

  describe '.openqa_results_relevant?' do
    context 'iso is nil' do
      before do
        allow_any_instance_of(ObsFactory::StagingProject).to receive(:iso).and_return(nil)
      end

      it { expect(staging_project_a).not_to be_openqa_results_relevant }
    end

    context 'iso is not nil' do
      before do
        allow_any_instance_of(ObsFactory::StagingProject).to receive(:iso).and_return('fake_content')
      end

      context 'overall_state == :building' do
        before do
          allow_any_instance_of(ObsFactory::StagingProject).to receive(:overall_state).and_return(:building)
        end

        it { expect(staging_project_a).not_to be_openqa_results_relevant }
      end

      context 'overall_state is not :building' do
        before do
          allow_any_instance_of(ObsFactory::StagingProject).to receive(:overall_state).and_return(:acceptable)
        end

        context 'without parent' do
          it { expect(staging_project_a).to be_openqa_results_relevant }

          context 'with overall_state is :empty' do
            before do
              allow_any_instance_of(ObsFactory::StagingProject).to receive(:overall_state).and_return(:empty)
            end

            it { expect(staging_project_a).not_to be_openqa_results_relevant }
          end
        end

        context 'with parent' do
          subject { ObsFactory::StagingProject.new(project: staging_a_dvd, distribution: factory_distribution) }

          it { expect(subject).to be_openqa_results_relevant }
        end
      end
    end
  end

  describe '.broken_packages' do
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{staging_a}/_result?code=failed&code=broken&code=unresolvable" }
    let(:backend_response) do
      %(<resultlist state='d797d177b6a6a9096ca39b01d40ab600'>
        <result project='openSUSE:Factory:Staging:A' repository='standard' arch='i586' code="#{status}" state="#{status}">
          <status package='kernel-obs-build' code='unresolvable'>
            <details>nothing provides kernel-pae-srchash = e33cb3e6860eb4d9ca8fa1a80d059a2f1caca8db</details>
          </status>
        </result>
        <result project='openSUSE:Factory:Staging:A' repository='standard' arch='x86_64' code='unpublished' state='unpublished'>
          <status package='firebird' code='failed'/>
          <status package='kmail' code='unresolvable'>
            <details>nothing provides libavcodec.so.57()(64bit) needed by libqt5-qtwebengine</details>
          </status>
        </result>
        <result project='openSUSE:Factory:Staging:A' repository='images' arch='x86_64' code='unpublished' state='unpublished'/>
      </resultlist>)
    end

    context 'with one repository in building state' do
      let(:status) { 'building' }

      before do
        stub_request(:get, backend_url).and_return(body: backend_response)
      end

      subject { staging_project_a }

      it { expect(subject.broken_packages.count).to eq(1) }
      it {
        expect(subject.broken_packages).to eq(
          [{ 'package' => 'firebird', 'project' => 'openSUSE:Factory:Staging:A', 'state' => 'failed',
              'details' => nil, 'repository' => 'standard', 'arch' => 'x86_64' }]
        )
      }
    end

    context 'without repository in building state' do
      let(:status) { 'unpublished' }
      let(:broken_packages_result) do
        [
          { 'package'    => 'kernel-obs-build',
            'project'    => 'openSUSE:Factory:Staging:A',
            'state'      => 'unresolvable',
            'details'    => 'nothing provides kernel-pae-srchash = e33cb3e6860eb4d9ca8fa1a80d059a2f1caca8db',
            'repository' => 'standard',
            'arch'       => 'i586' },
          { 'package'    => 'firebird',
            'project'    => 'openSUSE:Factory:Staging:A',
            'state'      => 'failed',
            'details'    => nil,
            'repository' => 'standard',
            'arch'       => 'x86_64' },
          { 'package'    => 'kmail',
            'project'    => 'openSUSE:Factory:Staging:A',
            'state'      => 'unresolvable',
            'details'    => 'nothing provides libavcodec.so.57()(64bit) needed by libqt5-qtwebengine',
            'repository' => 'standard',
            'arch'       => 'x86_64' }
        ]
      end

      before do
        stub_request(:get, backend_url).and_return(body: backend_response)
      end

      subject { staging_project_a }

      it { expect(subject.broken_packages.count).to eq(3) }
      it { expect(subject.broken_packages).to eq(broken_packages_result) }
    end
  end

  describe '.building_repositories' do
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{staging_a}/_result?code=failed&code=broken&code=unresolvable" }
    let(:backend_response) do
      %(<resultlist state='d797d177b6a6a9096ca39b01d40ab600'>
        <result project='openSUSE:Factory:Staging:A' repository='standard' arch='x86_64' code="#{status}" state="#{status}">
          <status package='firebird' code='failed'/>
          <status package='kmail' code='unresolvable'>
            <details>nothing provides libavcodec.so.57()(64bit) needed by libqt5-qtwebengine</details>
          </status>
        </result>
      </resultlist>)
    end
    let(:summary_backend_url) { "#{CONFIG['source_url']}/build/#{staging_a}/_result?view=summary&repository=standard&arch=x86_64" }
    let(:summary_backend_response) do
      %(<resultlist state='d797d177b6a6a9096ca39b01d40ab600'>
        <result project='openSUSE:Factory:Staging:A' repository='standard' arch='x86_64' code="#{status}" state="#{status}">
          <summary>
            <statuscount code='failed' count='1'/>
            <statuscount code='unresolvable' count='1'/>
            <statuscount code='building' count='24'/>
          </summary>
        </result>
      </resultlist>)
    end

    context 'with a repository in building state' do
      let(:status) { 'building' }

      before do
        stub_request(:get, backend_url).and_return(body: backend_response)
        stub_request(:get, summary_backend_url).and_return(body: summary_backend_response)
      end

      subject { staging_project_a }

      it { expect(subject.building_repositories.count).to eq(1) }
      it { expect(subject.building_repositories).to eq([{ 'repository' => 'standard', 'arch' => 'x86_64', 'code' => 'building', 'state' => 'building', :tobuild => 24, :final => 2 }]) }
    end

    context 'without a repository in building state' do
      let(:status) { 'unpublished' }

      before do
        stub_request(:get, backend_url).and_return(body: backend_response)
        stub_request(:get, summary_backend_url).and_return(body: summary_backend_response)
      end

      subject { staging_project_a }

      it { expect(subject.building_repositories).to eq([]) }
    end
  end

  # TODO: untracked_requests, open_requests

  describe '.selected_requests' do
    include_context 'a staging project with description'
    let(:bs_request_1) { create(:bs_request, number: 614_459) }
    let(:bs_request_2) { create(:bs_request, number: 614_471) }
    let!(:request_1) { ObsFactory::Request.new(bs_request_1) }
    let!(:request_2) { ObsFactory::Request.new(bs_request_2) }

    subject { ObsFactory::StagingProject.new(project: staging_h, distribution: factory_distribution) }

    it { expect(subject.selected_requests).to eq([request_1, request_2]) }
  end

  describe '.missing_reviews' do
    include_context 'a staging project with description'

    let(:user) { create(:user, login: 'king') }
    let(:bs_request_1) { create(:bs_request, number: 614_459) }
    let(:bs_request_2) { create(:bs_request, number: 614_471) }
    let!(:review_1) { create(:review, state: :accepted, bs_request: bs_request_1, by_user: user.login) }

    subject { ObsFactory::StagingProject.new(project: staging_h, distribution: factory_distribution) }

    context 'without missing reviews' do
      let!(:review_2) { create(:review, bs_request: bs_request_2, by_project: staging_h.name) }

      it { expect(subject.missing_reviews).to eq([]) }
    end

    context 'with missing reviews' do
      let!(:review_2) { create(:review, bs_request: bs_request_2, by_user: user.login) }

      it { expect(subject.missing_reviews).to eq([{ id: review_2.id, request: 614_471, state: 'new', package: nil, by: 'king' }]) }
    end
  end

  describe '.meta' do
    include_context 'a staging project with description'

    let(:meta_result) do
      { 'requests' =>
                              [
                                {
                                  'author'  => 'iznogood',
                                  'id'      => 614_459,
                                  'package' => 'latexila',
                                  'type'    => 'delete'
                                },
                                {
                                  'author'  => 'dirkmueller',
                                  'id'      => 614_471,
                                  'package' => 'iprutils',
                                  'type'    => 'submit'
                                }
                              ],
        'requests_comment' => 13_492,
        'splitter_info'    => {
          'activated' => '2018-06-06 05:33:43.433155',
          'group'     => 'all',
          'strategy'  => { 'name' => 'none' }
        } }
    end

    subject { ObsFactory::StagingProject.new(project: staging_h, distribution: factory_distribution) }

    it { expect(subject.meta).to eq(meta_result) }
  end

  # TODO: self.attributes

  describe '.build_state' do
    subject { staging_project_a }

    it { expect(subject.build_state).to eq(:acceptable) }

    context 'with building repository' do
      before do
        allow_any_instance_of(ObsFactory::StagingProject).to receive(:building_repositories).and_return(['fake_content'])
      end

      it { expect(subject.build_state).to eq(:building) }
    end

    context 'with broken packages' do
      before do
        allow_any_instance_of(ObsFactory::StagingProject).to receive(:broken_packages).and_return(['fake_content'])
      end

      it { expect(subject.build_state).to eq(:failed) }
    end
  end

  describe '.iso' do
    context 'with iso' do
      let(:backend_url) { "#{CONFIG['source_url']}/build/#{staging_a}/_result?view=binarylist&package=Test-DVD-x86_64&repository=images" }
      let(:backend_response) do
        %(<resultlist state='d797d177b6a6a9096ca39b01d40ab600'>
          <result project='openSUSE:Factory:Staging:A' repository='images' arch='x86_64' code='unpublished' state='unpublished'>
            <binarylist package='Test-DVD-x86_64'>
              <binary filename='Test-Build1039.1-Media.iso' size='879214592' mtime='1528427209'/>
              <binary filename='Test-Build1039.1-Media.iso.sha256' size='623' mtime='1528427215'/>
              <binary filename='Test-Build1039.1-Media.report' size='371629' mtime='1528427188'/>
              <binary filename='_channel' size='64345' mtime='1528427189'/>
              <binary filename='_statistics' size='716' mtime='1528427188'/>
            </binarylist>
          </result>
        </resultlist>)
      end

      before do
        stub_request(:get, backend_url).and_return(body: backend_response)
      end

      subject { staging_project_a }

      it { expect(subject.iso).to eq('openSUSE-Staging:A-Staging-DVD-x86_64-Build1039.1-Media.iso') }
    end

    context 'without iso' do
      subject { staging_project_a }

      it { expect(subject.iso).to be_nil }
    end
  end

  describe '.openqa_state' do
    context 'with acceptable results' do
      context 'when the project is ADI' do
        let(:staging_adi) { create(:project, name: 'openSUSE:Factory:Staging:adi:15') }
        subject { staging_project_adi }

        it { expect(subject.openqa_state).to eq(:acceptable) }
      end

      context 'when all the job results passed' do
        subject { staging_project_a }

        before do
          allow_any_instance_of(ObsFactory::StagingProject).to receive(:openqa_jobs).and_return(
            [ObsFactory::OpenqaJob.new(result: 'softfailed'), ObsFactory::OpenqaJob.new(result: 'passed')]
          )
        end

        it { expect(subject.openqa_state).to eq(:acceptable) }
      end
    end

    context 'with testing results' do
      subject { staging_project_a }

      context "when doesn't have openqa jobs" do
        before do
          allow_any_instance_of(ObsFactory::StagingProject).to receive(:openqa_jobs).and_return([])
        end

        it { expect(subject.openqa_state).to eq(:testing) }
      end

      context 'when openqa jobs has at least one result with none' do
        before do
          allow_any_instance_of(ObsFactory::StagingProject).to receive(:openqa_jobs).and_return([ObsFactory::OpenqaJob.new(result: 'none'), ObsFactory::OpenqaJob.new(result: 'passed')])
        end

        it { expect(subject.openqa_state).to eq(:testing) }
      end
    end

    context 'with failing results' do
      before do
        allow_any_instance_of(ObsFactory::StagingProject).to receive(:openqa_jobs).and_return([ObsFactory::OpenqaJob.new(result: 'failed'), ObsFactory::OpenqaJob.new(result: 'passed')])
      end

      subject { staging_project_a }

      it { expect(subject.openqa_state).to eq(:failed) }
    end
  end

  describe '.overall_state' do
    before do
      allow(staging_project_a).to receive(:selected_requests).and_return(['fake_content'])
      allow(staging_project_a).to receive(:obsolete_requests).and_return([])
      allow(staging_project_a).to receive(:untracked_requests).and_return([])
    end

    context 'without selected_requests' do
      before do
        allow(staging_project_a).to receive(:selected_requests).and_return([])
      end

      it { expect(staging_project_a.overall_state).to eq(:empty) }
    end

    context 'with untracked requests' do
      before do
        allow(staging_project_a).to receive(:untracked_requests).and_return(['fake_content'])
      end

      it { expect(staging_project_a.overall_state).to eq(:unacceptable) }
    end

    context 'with obsolete requests request' do
      before do
        allow(staging_project_a).to receive(:obsolete_requests).and_return(['fake_content'])
      end

      it { expect(staging_project_a.overall_state).to eq(:unacceptable) }
    end

    context 'when depends on build state' do
      context 'and has building repositories' do
        before do
          allow(staging_project_a).to receive(:build_state).and_return(:building)
        end

        it { expect(staging_project_a.overall_state).to eq(:building) }
      end

      context 'and has broken packages' do
        before do
          allow(staging_project_a).to receive(:build_state).and_return(:failed)
        end

        it { expect(staging_project_a.overall_state).to eq(:failed) }
      end
    end

    context 'when build_state is accepted' do
      before do
        allow(staging_project_a).to receive(:build_state).and_return(:acceptable)
      end

      context 'and openqa state has failing modules' do
        before do
          allow(staging_project_a).to receive(:openqa_state).and_return(:failed)
        end

        it { expect(staging_project_a.overall_state).to eq(:failed) }
      end

      context 'and openqa state still testing' do
        before do
          allow(staging_project_a).to receive(:openqa_state).and_return(:testing)
        end

        it { expect(staging_project_a.overall_state).to eq(:testing) }
      end

      context 'and openqa state is acceptable' do
        before do
          allow(staging_project_a).to receive(:openqa_state).and_return(:acceptable)
          allow(staging_project_a).to receive(:subproject).and_return(nil)
        end

        context "and doesn't have subproject and missing_reviews" do
          before do
            allow(staging_project_a).to receive(:missing_reviews).and_return([])
          end

          it { expect(staging_project_a.overall_state).to eq(:acceptable) }
        end

        context 'and have missing_reviews' do
          before do
            allow(staging_project_a).to receive(:missing_reviews).and_return(['fake content'])
          end

          it { expect(staging_project_a.overall_state).to eq(:review) }
        end
      end
    end
  end
end
