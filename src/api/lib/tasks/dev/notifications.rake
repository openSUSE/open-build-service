namespace :dev do
  namespace :notifications do
    # Run this task with: rails "dev:notifications:data[3]"
    # replacing 3 with any number to indicate how many times you want this code to be executed.
    desc 'Creates a notification and all its dependencies'
    task :data, [:repetitions] => :development_environment do |_t, args|
      args.with_defaults(repetitions: 1)
      repetitions = args.repetitions.to_i
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      # Users
      admin = User.where(login: 'Admin').first || create(:admin_user, login: 'Admin')
      group = create(:groups_user, user: admin, group: create(:group, title: Faker::Lorem.word)).group
      RakeSupport.subscribe_to_all_notifications(admin)
      requestor = User.where(login: 'Requestor').first || create(:confirmed_user, login: 'Requestor')
      User.session = requestor

      # Projects
      admin_home_project = admin.home_project || RakeSupport.create_and_assign_project(admin.home_project_name, admin)
      requestor_project = Project.find_by(name: 'requestor_project') || RakeSupport.create_and_assign_project('requestor_project', requestor)

      repetitions.times do |repetition|
        package_name = "package_#{Time.now.to_i}_#{repetition}"
        admin_package = create(:package_with_file, name: package_name, project: admin_home_project)
        requestor_package = create(:package_with_file, name: admin_package.name, project: requestor_project)

        # Will create a notification (RequestCreate event) for this request.
        request = create(
          :bs_request_with_submit_action,
          creator: requestor,
          target_project: admin_home_project,
          target_package: admin_package,
          source_project: requestor_project,
          source_package: requestor_package
        )

        # Will create notifications (ReviewWanted event) for those reviews.
        # The creation and these two reviews are finally displayed as
        # one single notification in the UI.
        request.addreview(by_user: admin, comment: Faker::Lorem.paragraph)
        request.addreview(by_group: group, comment: Faker::Lorem.paragraph)

        # Will create a notification (CommentForRequest event) for this comment.
        create(:comment_request, commentable: request, user: requestor)
        # Will create a notification (CommentForProject event) for this comment.
        create(:comment_project, commentable: admin_home_project, user: requestor)
        # Will create a notification (CommentForPackage event) for this comment.
        create(:comment_package, commentable: admin_package, user: requestor)

        # Admin requests changes to requestor, so a RequestStatechange notification will appear
        # as soon as the requestor changes the state of the request.
        request2 = create(
          :bs_request_with_submit_action,
          creator: admin,
          target_project: requestor_project,
          target_package: requestor_package,
          source_project: admin_home_project,
          source_package: admin_package
        )
        # Will create a notification (RequestStatechange event) for this request change.
        request2.change_state(newstate: ['accepted', 'declined'].sample, force: true, user: requestor.login, comment: 'Declined by requestor')

        # Process notifications immediately to see them in the web UI
        SendEventEmailsJob.new.perform_now
      end
    end
  end
end
