# Running `dev:test_data:maintenance` as part of the `rails dev:test_data`
# will create all the elements related to maintenance:

# - Maintained project (GA Project): i.e. openSUSE:Leap:15.4
# - Update Project: i.e. openSUSE:Leap:15.4:Update
# - User's branch of the Update Project: i.e. home:Iggy:branches:openSUSE:Leap:15.4:Update
# - Maintenance Project: i.e. openSUSE:Maintenance
# - Incident Project: i.e. openSUSE:Maintenance:100
# - Maintenance Incident Request.
# - Maintenance Release Request.

module TestData
  module Maintenance
    def create_maintenance_project(project_name)
      admin = User.get_default_admin
      leap = Project.find_by(name: project_name)

      update_project = create(:update_project, target_project: leap, name: "#{leap.name}:Update", commit_user: admin)
      create(
        :maintenance_project,
        name: 'MaintenanceProject',
        title: 'official maintenance space',
        target_project: update_project,
        maintainer: admin,
        commit_user: admin
      )
    end

    def request_with_incident_actions
      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      request = build(
        :bs_request_with_maintenance_incident_action,
        creator: iggy
      )

      maintenance_project = Project.find_by(kind: 'maintenance')
      release_project = Project.find_by(kind: 'maintenance_release')

      # This is the first maintenance incident action, we reuse the action created by the factory
      home_iggy_project = RakeSupport.find_or_create_project(iggy.home_project_name, iggy)
      maintenance_package = create(:package, name: "maintenance_package_#{Faker::Lorem.word}", project: home_iggy_project, commit_user: iggy)

      User.session = iggy
      request.bs_request_actions.first.tap do |action|
        action.source_project = home_iggy_project
        action.source_package = maintenance_package
        action.target_project = maintenance_project
        action.target_releaseproject = release_project
        action.save!
      end

      # This is the second maintenance incident action
      another_maintenance_package = create(:package, name: "another_maintenance_package_#{Faker::Lorem.word}", project: home_iggy_project, commit_user: iggy)
      request.bs_request_actions << create(:bs_request_action,
                                           type: :maintenance_incident,
                                           source_project: home_iggy_project,
                                           source_package: another_maintenance_package,
                                           target_project: maintenance_project,
                                           target_releaseproject: release_project)

      puts "* Request with maintenance incident actions #{request.number} has been created."
    end
  end
end
