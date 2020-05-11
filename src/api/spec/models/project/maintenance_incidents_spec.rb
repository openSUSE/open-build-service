require 'rails_helper'
require 'rantly/rspec_extensions'

RSpec.describe Project, vcr: true do
  let(:maintenance_incident) { create(:maintenance_incident_project) }
  let!(:target_repo_1) { create(:repository_with_release_target, project: maintenance_incident) }
  let!(:target_repo_2) { create(:repository_with_release_target, project: maintenance_incident) }

  describe '#packages_with_release_target' do
    let(:package_1) { create(:package, name: "my_package_1.#{target_repo_1}", project: maintenance_incident) }
    let!(:build_flag_1) { create(:build_flag, package: package_1, repo: target_repo_1) }
    let(:package_2) { create(:package, name: "my_package_2.#{target_repo_2}", project: maintenance_incident) }
    let!(:build_flag_2) { create(:build_flag, package: package_2, repo: target_repo_2) }
    let(:package_3) { create(:package, name: "my_package_3.#{target_repo_2}", project: maintenance_incident) }

    subject { maintenance_incident.packages_with_release_target }

    context 'returns all packages that build for release target repositories of the incident' do
      it { is_expected.to contain_exactly(package_1, package_2) }
    end
  end
end
