require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ObsFactory::ObsProject do
  let(:project) { create(:project, name: 'openSUSE:Factory') }

  subject { ObsFactory::ObsProject.new(project.name, 'My nickname') }

  describe '::new' do
    it { expect(subject.project).to eq(project) }
    it { expect(subject.nickname).to eq('My nickname') }
  end

  describe '#name' do
    it { expect(subject.name).to eq(project.name) }
  end

  context 'project has a buildresult' do
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{project}/_result?view=summary" }

    before do
      stub_request(:get, backend_url).and_return(body:
      %(<resultlist state="dea55075a09a8497bad40a28c01cfdad">
          <result project="#{project}" repository="openSUSE" arch="i586" code="published" state="published">
            <summary>
              <statuscount code="succeeded" count="5"/>
            </summary>
          </result>
          <result project="#{project}" repository="SLES" arch="i586" code="published" state="published">
            <summary>
              <statuscount code="succeeded" count="5"/>
            </summary>
          </result>
        </resultlist>))
    end

    describe '#repos' do
      it { expect(subject.repos).to contain_exactly('openSUSE', 'SLES') }
    end

    describe '#build_summary' do
      it 'returns the build results of a project' do
        expect(subject.build_summary['result']).to eq(
          [
            {
              'project' => 'openSUSE:Factory',
              'repository' => 'openSUSE',
              'arch' => 'i586',
              'code' => 'published',
              'state' => 'published',
             'summary' => { 'statuscount' => { 'code' => 'succeeded', 'count' => '5' } }
            },
            {
              'project' => 'openSUSE:Factory',
              'repository' => 'SLES',
              'arch' => 'i586',
              'code' => 'published',
              'state' => 'published',
             'summary' => { 'statuscount' => { 'code' => 'succeeded', 'count' => '5' } }
            }
          ]
        )
      end
    end
  end

  describe '#build_failures_count' do
    let(:backend_url) { "#{CONFIG['source_url']}/build/#{project}/_result?code=failed&code=broken&code=unresolvable" }

    before do
      stub_request(:get, backend_url).and_return(body:
      %(<resultlist state="dea55075a09a8497bad40a28c01cfdad">
          <result project="#{project}" repository="openSUSE" arch="i586" code="blocked" state="blocked">
            <status package='package_1' code='broken' />
            <status package='package_2' code='failed' />
            <status package='package_3' code='unresolvable' />
          </result>
        </resultlist>))
    end

    it { expect(subject.build_failures_count).to eq(3) }
  end
end
