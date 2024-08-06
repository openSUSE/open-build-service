namespace :dev do
  namespace :notifications do
    desc 'Creates a notification and all its dependencies. Specify amount with [N], like rake "dev:notifications:data[3]"'
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

      # Create notification for roles revoked
      iggy = User.find_by(login: 'Iggy') || create(:confirmed_user, :with_home, login: 'Iggy')
      iggy.run_as do
        home_project_iggy = Project.find_by(name: 'home:Iggy')
        role = Role.find_by_title!('maintainer')
        Relationship::AddRole.new(home_project_iggy, role, check: true, user: admin).add_role
        home_project_iggy.store
        home_project_iggy.remove_role(admin, role)
        home_project_iggy.store
      end

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
        request2.change_state(newstate: %w[accepted declined].sample, force: true, user: requestor.login, comment: 'Declined by requestor')

        # Create notifications for build failures
        Event::BuildFail.create({ project: admin_home_project.name, package: package_name, repository: "#{Faker::Lorem.word}_repo", arch: "#{Faker::Lorem.word}_arch", reason: 'meta change' })

        # Add admin to a group to generate a Event::AddedUserToGroup.
        another_group = create(:group, title: Faker::Lorem.words.map(&:capitalize).join)
        another_group.users << admin

        # Admin is already subscribed as token_executor, Iggy and another_group are now subscribed as token_member
        iggy = User.find_by(login: 'Iggy')
        create(:event_subscription_workflow_run_fail, channel: :web, user: iggy, receiver_role: 'token_member')
        token = Token.find_by(executor: admin)
        token.users << iggy # share token with iggy
        token.groups << another_group
        create(:workflow_run, :failed, token: token)

        # Process notifications immediately to see them in the web UI
        SendEventEmailsJob.new.perform_now
      end
    end
  end
end
