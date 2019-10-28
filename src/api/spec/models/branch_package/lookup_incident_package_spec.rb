require 'rails_helper'

RSpec.describe BranchPackage::LookupIncidentPackage, vcr: false do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

  before do
    login user
  end

  describe 'incident_package' do
    let(:link_target_project) { create(:project, name: 'openSUSE:Maintenance') }
    let(:maintenance_project) { create(:maintenance_project, target_project: link_target_project) }
    let(:package_1) { create(:package, name: 'chromium', project: link_target_project) }
    let!(:lookup_incident_package) do
      BranchPackage::LookupIncidentPackage.new(package: package_1,
                                               maintenance_project: maintenance_project, link_target_project: link_target_project)
    end
    let(:xml_response) do
      <<~XML_BODY
        <collection>
          <package name=\"chromium.openSUSE_Leap_15.1_Update\" project=\"openSUSE:Maintenance:10258\"/>
          <package name=\"chromium.openSUSE_Leap_15.1_Update\" project=\"openSUSE:Maintenance:11261\"/>
        </collection>
      XML_BODY
    end

    before do
      allow(Backend::Api::Search).to receive(:incident_packages).and_return(xml_response)
    end

    subject { lookup_incident_package.incident_packages(link_target_project) }

    it { expect(subject.xpath('//collection')).not_to be_empty }
    it { expect(subject.xpath('//collection//package').count).to eq(2) }
  end

  describe 'possible_incidents' do
    let!(:project_1) do
      create(:project_with_package, package_name: 'chromium.openSUSE_Leap_15.1_Update',
                                    name: 'openSUSE:Maintenance:11261')
    end
    let(:lookup_incident_package) { BranchPackage::LookupIncidentPackage.new(package: 'chromium', link_target_project: 'openSUSE:Leap:15.01:Update') }

    let(:xml_response) do
      <<~XML_BODY
        <collection>
          <package name=\"chromium.openSUSE_Leap_15.1_Update\" project=\"openSUSE:Maintenance:11261\"/>
        </collection>
      XML_BODY
    end

    before do
      allow_any_instance_of(BranchPackage::LookupIncidentPackage).to receive(:incident_packages).and_return(Nokogiri::XML(xml_response))
      allow(Package).to receive(:find_by_project_and_name).with(project_1.name, project_1.packages.first.name).and_return(project_1.packages.first)
      allow_any_instance_of(Project).to receive(:is_maintenance_incident?).and_return(true)
      allow(Package).to receive(:find_by_project_and_name).with(project_1.name, project_1.packages.first.name).and_return(project_1.packages.first)
    end

    subject { lookup_incident_package.possible_incidents('openSUSE:Maintenance') }

    it { expect(subject).to be_instance_of(Array) }
    it { expect(subject).not_to be_empty }
    it { expect(subject).to include(11_261) }
  end

  describe 'last_incident' do
    let(:link_target_project) { create(:project, name: 'openSUSE:Maintenance') }
    let(:maintenance_project) { create(:maintenance_project, target_project: link_target_project) }
    let(:lookup_incident_package) { BranchPackage::LookupIncidentPackage.new(package: 'chromium', link_target_project: link_target_project) }
    before do
      allow_any_instance_of(BranchPackage::LookupIncidentPackage).to receive(:possible_incidents).and_return([1, 3, 9, 7])
      allow_any_instance_of(BranchPackage::LookupIncidentPackage).to receive(:maintenance_projects).and_return([maintenance_project])
    end

    subject { lookup_incident_package.last_incident }

    it { expect(subject).to eq(9) }
  end
end
