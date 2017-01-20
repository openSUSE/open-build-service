require 'rails_helper'

RSpec.describe MaintenanceStatistic do

  context '#find_by_project' do
    let(:admin_user) { create(:admin_user) }
    let(:user) { create(:confirmed_user, login: 'tom') }
    let(:maintenance_coord_user) { create(:confirmed_user, login: 'maintenance_coord') }
    let(:project) { create(:project_with_repository, name: 'ProjectWithRepo') }
    let(:package) { create(:package_with_file, project: project, name: 'ProjectWithRepo_package') }
    let(:update_project) { create(:update_project, target_project: project, name: "#{project.name}:Update") }
    let(:maintenance_project) {
      create(:maintenance_project,
             name: 'MaintenanceProject',
             title: 'official maintenance space',
             target_project: update_project,
             create_patchinfo: true,
             maintainer: maintenance_coord_user)
    }

    before do
      # Branch package
      BranchPackage.new(project: update_project.name, package: package.name)

      # change sources
      Suse::Backend.put("/source/home:tom:branches:ProjectWithRepo:Update/ProjectWithRepo_package/DUMMY_FILE", "dummy")

      # create maintenance incident
      MaintenanceIncident.build_maintenance_incident(project)

      # Accept maintenance incident
      maintenance_incident = BsRequest.last
      maintenance_incident.change_state({ newstate: :accept })

      # Create release request
      release_request = BsRequest.new
      release_request.description = params[:description]
      action = BsRequestActionMaintenanceRelease.new({source_project: params[:project]})
      release_request.bs_request_actions << action
      action.bs_request = req
      release_request.save!

      # accept review

    end



  end
end
