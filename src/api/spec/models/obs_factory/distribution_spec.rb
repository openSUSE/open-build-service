require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ObsFactory::Distribution do
  let(:project) { create(:project, name: 'openSUSE:Factory') }
  let(:other_project) { create(:project, name: 'other_project') }
  let!(:distribution) { ObsFactory::Distribution.new(project) }

  describe '::new' do
    def strategy_for(name)
      ObsFactory::Distribution.new(create(:project, name: name)).strategy
    end

    it { expect(distribution.strategy).to                    be_kind_of ObsFactory::DistributionStrategyFactory }
    it { expect(strategy_for('openSUSE:Factory:PowerPC')).to be_kind_of ObsFactory::DistributionStrategyFactoryPPC }
    it { expect(strategy_for('openSUSE:42.3')).to            be_kind_of ObsFactory::DistributionStrategyOpenSUSE }
    it { expect(strategy_for('SUSE:SLE-12-SP1:GA')).to       be_kind_of ObsFactory::DistributionStrategySLE12SP1 }
    it { expect(strategy_for('SUSE:SLE-15:GA')).to           be_kind_of ObsFactory::DistributionStrategySLE15 }
    it { expect(strategy_for('SUSE:SLE-15-SP1:GA')).to       be_kind_of ObsFactory::DistributionStrategySLE15 }
    it { expect(strategy_for('SUSE:SLE-12-SP3:Update:Products:CASP20')).to be_kind_of ObsFactory::DistributionStrategyCasp }
  end

  describe 'self.attributes' do
    let(:result) do
      %w[name description staging_projects openqa_version openqa_group
         source_version totest_version published_version staging_manager
         standard_project live_project images_project ring_projects]
    end

    it { expect(ObsFactory::Distribution.attributes).to eq(result) }
  end

  describe 'self.find' do
    context 'with a project' do
      context 'with distribution' do
        subject { ObsFactory::Distribution.find(project.name) }

        it { expect(subject).to be_kind_of(ObsFactory::Distribution) }
        it { expect(subject.project).to eq(project) }
      end

      context 'without distribution' do
        subject { ObsFactory::Distribution.find(other_project.name) }

        it { expect(subject).to be_nil }
      end
    end

    context 'with a non-existant project' do
      subject { ObsFactory::Distribution.find('non-existant') }

      it { expect(subject).to be_nil }
    end
  end

  describe '#name' do
    it { expect(distribution.name).to eq(project.name) }
  end

  describe '#id' do
    it { expect(distribution.id).to eq(project.name) }
  end

  describe '#description' do
    it { expect(distribution.description).to eq(project.description) }
  end

  describe '#staging_projects' do
    context 'with staging projects' do
      let!(:staging_project) { create(:project, name: 'openSUSE:Factory:Staging') }
      let!(:staging_project_a) { create(:project, name: 'openSUSE:Factory:Staging:A') }
      let!(:staging_project_b) { create(:project, name: 'openSUSE:Factory:Staging:B') }
      let!(:staging_project_c) { create(:project, name: 'openSUSE:Factory:Staging:C') }
      let!(:staging_project_345) { create(:project, name: 'openSUSE:Factory:Staging:345') }

      let(:result) { [staging_project_a, staging_project_b, staging_project_c] }

      subject { distribution.staging_projects.map(&:project) }

      it { expect(subject).to eq(result) }
    end

    context 'without staging projects' do
      it { expect(distribution.staging_projects).to be_empty }
    end
  end

  describe '#staging_projects_all' do
    context 'with staging projects' do
      let!(:staging_project) { create(:project, name: 'openSUSE:Factory:Staging') }
      let!(:staging_project_a) { create(:project, name: 'openSUSE:Factory:Staging:A') }
      let!(:staging_project_b) { create(:project, name: 'openSUSE:Factory:Staging:B') }
      let!(:staging_project_c) { create(:project, name: 'openSUSE:Factory:Staging:C') }
      let!(:staging_project_345) { create(:project, name: 'openSUSE:Factory:Staging:345') }

      let(:result) { [staging_project_a, staging_project_b, staging_project_c, staging_project_345] }

      subject { distribution.staging_projects_all }

      it 'returns the list of ObsFactory::StagingProject instances' do
        expect(subject).to all(be_kind_of(ObsFactory::StagingProject))
        expect(subject.map(&:project)).to contain_exactly(*result)
      end
    end

    context 'without staging projects' do
      it { expect(distribution.staging_projects_all).to be_empty }
    end
  end

  describe '#source_version' do
    context 'with a opensuse product' do
      include_context 'a opensuse product'

      let(:backend_url) { "#{CONFIG['source_url']}/source/#{distribution.project}/000product/openSUSE.product" }

      before do
        stub_request(:get, backend_url).and_return(body: opensuse_product)
      end

      it { expect(distribution.source_version).to eq('20180605') }
    end
  end

  describe '#request_with_reviews_for' do
    let(:target_package) { create(:package, name: 'target_package', project: project) }
    let(:source_project) { create(:project, name: 'source_project') }
    let(:source_package) { create(:package, name: 'source_package', project: source_project) }

    context 'user' do
      let(:user) { create(:user, login: 'Jim') }
      let(:other_user) { create(:user, login: 'Other') }
      let!(:review_request) do
        create(:review_bs_request,
               reviewer: user.login,
               target_project: project.name,
               target_package: target_package.name,
               source_project: source_package.project.name,
               source_package: source_package.name)
      end
      let!(:other_review_request) do
        create(:review_bs_request,
               reviewer: other_user.login,
               target_project: project.name,
               target_package: target_package.name,
               source_project: source_package.project.name,
               source_package: source_package.name)
      end

      subject { distribution.requests_with_reviews_for_user(user.login) }

      it { expect(subject.count).to eq(1) }
      it { expect(subject.first.class).to eq(ObsFactory::Request) }
      it { expect(subject.first.bs_request).to eq(review_request) }
    end

    context 'group' do
      let(:group) { create(:group, title: 'Staff') }
      let(:other_group) { create(:group, title: 'Other') }
      let!(:review_request) do
        create(:review_bs_request_by_group,
               reviewer: group.title,
               target_project: project.name,
               target_package: target_package.name,
               source_project: source_package.project.name,
               source_package: source_package.name)
      end
      let!(:other_review_request) do
        create(:review_bs_request_by_group,
               reviewer: other_group.title,
               target_project: project.name,
               target_package: target_package.name,
               source_project: source_package.project.name,
               source_package: source_package.name)
      end

      subject { distribution.requests_with_reviews_for_group(group.title) }

      it { expect(subject.count).to eq(1) }
      it { expect(subject.first.class).to eq(ObsFactory::Request) }
      it { expect(subject.first.bs_request).to eq(review_request) }
    end
  end

  describe '#standard_project' do
    it { expect(distribution.standard_project.class).to eq(ObsFactory::ObsProject) }
    it { expect(distribution.standard_project.exclusive_repository).to eq('standard') }
  end

  describe '#live_project' do
    context 'with live project' do
      let!(:live_project) { create(:project, name: 'openSUSE:Factory:Live') }

      it { expect(distribution.live_project.class).to eq(ObsFactory::ObsProject) }
      it { expect(distribution.live_project.exclusive_repository).to eq('images') }
    end

    context 'without live project' do
      it { expect(distribution.live_project).to be_nil }
    end
  end

  describe '#images_project' do
    it { expect(distribution.images_project).to be_kind_of(ObsFactory::ObsProject) }
    it { expect(distribution.images_project.exclusive_repository).to eq('images') }
  end

  describe '#ring_projects' do
    context 'with ring projects' do
      let!(:ring_project) { create(:project, name: 'openSUSE:Factory:Rings') }
      let!(:ring_project_0) { create(:project, name: 'openSUSE:Factory:Rings:0-Bootstrap') }
      let!(:ring_project_1) { create(:project, name: 'openSUSE:Factory:Rings:1-MinimalX') }
      let(:ring_projects) do
        [ring_project_0, ring_project_1]
      end

      subject { distribution.ring_projects }

      it 'returns the list of ObsFactory::ObsProject instances' do
        expect(subject).to all(be_kind_of(ObsFactory::ObsProject))
        expect(subject.map(&:project)).to contain_exactly(*ring_projects)
      end
    end
  end

  describe '#rings_project_name' do
    it { expect(distribution.rings_project_name).to eq('openSUSE:Factory:Rings') }
  end

  describe '#openqa_filter' do
    let(:staging_project_a) { create(:project, name: 'openSUSE:Factory:Staging:A') }
    let(:staging_project) { ObsFactory::StagingProject.new(project: staging_project_a, distribution: distribution) }

    it { expect(distribution.openqa_filter(staging_project)).to eq('match=Staging:A') }
  end

  describe '#openqa_jobs_for' do
    before do
      allow(ObsFactory::OpenqaJob).to receive(:find_all_by)
    end

    shared_examples 'calls find_all_by' do |version, expected_build|
      it "performs find_all_by with #{version} version" do
        allow(distribution).to receive("#{version}_version").and_return(expected_build)
        distribution.openqa_jobs_for(version)
        expect(ObsFactory::OpenqaJob).to have_received(:find_all_by).with({ distri: 'opensuse', version: 'Tumbleweed', build: expected_build, group: 'openSUSE Tumbleweed' },
                                                                          exclude_modules: true)
      end
    end

    include_examples 'calls find_all_by', 'totest', '20180701'
    include_examples 'calls find_all_by', 'published', '20180702'
    include_examples 'calls find_all_by', 'source', '20180703'
  end
end
