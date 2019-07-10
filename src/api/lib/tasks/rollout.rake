# rubocop:disable Rails/SkipsModelValidations
namespace :rollout do
  desc 'Move all the users to rollout program'
  task :all_on do
    User.all_without_nobody.where(in_rollout: false).in_batches.update_all(in_rollout: true)
  end

  desc 'Move all the users out of the rollout program'
  task :all_off do
    User.where(in_rollout: true).in_batches.update_all(in_rollout: false)
  end

  desc 'Move the users already in beta to rollout program'
  task :from_beta do
    User.where(in_beta: true, in_rollout: false).in_batches.update_all(in_rollout: true)
  end

  desc 'Move the members of groups to rollout program'
  task :from_groups do
    User.where(in_rollout: false).joins(:groups_users).distinct.in_batches.update_all(in_rollout: true)
  end

  desc 'Move the users with recent activity to rollout program'
  task :recently_logged_users do
    User.all_without_nobody
        .where(in_rollout: false, last_logged_in_at: 3.months.ago.midnight..Time.zone.now)
        .in_batches.update_all(in_rollout: true)
  end

  desc 'Move the users without recent activity to rollout program'
  task :non_recently_logged_users do
    User.all_without_nobody
        .where.not(in_rollout: true, last_logged_in_at: 3.months.ago.midnight..Time.zone.now)
        .in_batches.update_all(in_rollout: true)
  end
end
# rubocop:enable Rails/SkipsModelValidations
