require 'rantly/rspec_extensions'

RSpec.describe Project, :vcr do
  let(:maintenance_incident) { create(:maintenance_incident_project) }
  let!(:target_repo1) { create(:repository_with_release_target, project: maintenance_incident) }
  let!(:target_repo2) { create(:repository_with_release_target, project: maintenance_incident) }

  describe '#packages_with_release_target' do
    subject { maintenance_incident.packages_with_release_target }

    let(:package1) { create(:package, name: "my_package_1.#{target_repo1}", project: maintenance_incident) }
    let!(:build_flag1) { create(:build_flag, package: package1, repo: target_repo1) }
    let(:package2) { create(:package, name: "my_package_2.#{target_repo2}", project: maintenance_incident) }
    let!(:build_flag2) { create(:build_flag, package: package2, repo: target_repo2) }
    let(:package3) { create(:package, name: "my_package_3.#{target_repo2}", project: maintenance_incident) }

    context 'returns all packages that build for release target repositories of the incident' do
      it { is_expected.to contain_exactly(package1, package2) }
    end
  end
end
