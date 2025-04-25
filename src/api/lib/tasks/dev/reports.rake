#!/usr/bin/env ruby

namespace :dev do
  namespace :reports do
    desc 'Create reports for several contents like Comments, Packages, Projects and Users'
    task data: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      factory = Project.where(name: 'openSUSE:Factory').first
      admin = User.default_admin
      iggy = User.find_by(login: 'Iggy')
      [
        factory.comments.create!(user: admin, body: 'This project is crap!'),
        create(:package_with_files, name: 'crappy_package', project: factory),
        create(:project, name: 'some_crappy_project_name', commit_user: admin),
        create(:confirmed_user, login: 'crapboy')
      ].each do |reportable|
        Report.create!(reportable: reportable, reporter: iggy, reason: 'Watch your language, please')
      end

      source_project = create(:project, :as_submission_source, name: 'source_project')
      source_package = create(:package_with_files,
                              name: 'package_a',
                              project: source_project,
                              changes_file_content: '- Fixes ------')
      target_project = create(:project, name: 'target_project')
      target_package = create(:package, name: 'target_package', project: target_project)
      user1 = User.find_by(login: 'user_1')
      [
        create(:bs_request_with_submit_action,
               creator: user1,
               target_package: target_package,
               source_package: source_package,
               description: 'Hey! Visit my new site $$$!')
      ].each do |reportable|
        Report.create!(reportable: reportable, reporter: user1, reason: 'This is a scam')
      end
    end

    # Run `rake dev:reports:decisions` (always after running `rake dev:reports:data`)
    desc 'Create decisions and appeal related to existing reports'
    task decisions: :development_environment do
      require 'factory_bot'
      include FactoryBot::Syntax::Methods

      # This automatically subscribes everyone to the cleared and favored decision events
      EventSubscription.create!(eventtype: Event::Decision.name, channel: :web, receiver_role: :reporter, enabled: true)
      EventSubscription.create!(eventtype: Event::Decision.name, channel: :web, receiver_role: :offender, enabled: true)

      admin = User.default_admin

      Report.find_each do |report|
        # Reports with even id will be 'cleared' (0). Those with odd id will be 'favor' (1).
        Decision.create!(reason: "Just because! #{report.id}", moderator: admin, type: Decision::TYPES[(report.id % 2)], reports: [report])
      end

      # The same decision applies to more than one report about the same object/reportable.
      reportable = Decision.first.reports.first.reportable
      another_user = User.find_by(login: 'Requestor') || create(:confirmed_user, login: 'Requestor')
      another_report = Report.create!(reportable: reportable, reporter: another_user, reason: 'Behave properly, please!')
      Decision.first.reports << another_report

      # Create an appeal against a favored decision and subscribe moderators to it
      EventSubscription.create!(eventtype: Event::AppealCreated.name, channel: :web, receiver_role: :moderator, enabled: true)
      report_with_favored_decision = Report.where(reportable_type: 'User').joins(:decision).where(decision: { type: 'DecisionFavored' }).first
      favored_decision = report_with_favored_decision.decision
      Appeal.create(appellant: report_with_favored_decision.reportable, decision: favored_decision, reason: 'I do not agree with the decision.')
    end
  end
end
