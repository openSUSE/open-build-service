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
      update_project = Project.find_by(name: "#{project_name}:Update")

      create(
        :maintenance_project,
        name: 'openSUSE:Maintenance',
        title: 'official openSUSE maintenance space',
        target_project: update_project,
        maintainer: admin,
        commit_user: admin
      )
    end

    def create_update_project(project_name)
      admin = User.get_default_admin

      leap = Project.find_by(name: project_name)
      create(:update_project, target_project: leap, name: "#{leap.name}:Update", commit_user: admin)
    end

    def request_with_incident_actions
      iggy = User.find_by(login: 'Iggy') || create(:staff_user, login: 'Iggy')
      request = build(
        :bs_request_with_maintenance_incident_action,
        creator: iggy
      )

      maintenance_project = Project.find_by(kind: 'maintenance') # i.e openSUSE:Maintenance
      update_project = Project.find_by(kind: 'maintenance_release') # i.e openSUSE:Leap:15.4:Update

      update_project_branch = RakeSupport.find_or_create_project(iggy.branch_project_name(update_project.name), iggy) # i.e. home:Iggy:branches:openSUSE:Leap:15.4:Update
      maintenance_package = create(:package, name: "maintenance_package_#{Faker::Lorem.word}", project: update_project_branch, commit_user: iggy)

      # This is the first maintenance incident action
      User.session = iggy
      request.bs_request_actions.first.tap do |action|
        action.source_project = update_project_branch
        action.source_package = maintenance_package
        action.target_project = maintenance_project
        action.target_releaseproject = update_project
        action.save!
      end

      # This is the second maintenance incident action
      another_maintenance_package = create(:package, name: "another_maintenance_package_#{Faker::Lorem.word}", project: update_project_branch, commit_user: iggy)
      request.bs_request_actions << create(:bs_request_action,
                                           type: :maintenance_incident,
                                           source_project: update_project_branch,
                                           source_package: another_maintenance_package,
                                           target_project: maintenance_project,
                                           target_releaseproject: update_project)

      puts "* Request #{request.number} with maintenance incident actions has been created."
    end

    def create_maintenance_setup
      leap = create(:project, name: 'openSUSE:Leap:15.4')
      create(:repository, project: leap, name: 'openSUSE_Tumbleweed', architectures: ['x86_64'])
      create_maintenance_project('openSUSE:Leap:15.4')
      create_update_project('openSUSE:Leap:15.4')
      request_with_incident_actions
    end
  end
end
