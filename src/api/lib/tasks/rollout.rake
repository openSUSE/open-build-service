# rubocop:disable Rails/SkipsModelValidations

# Follow the recommendations for the rollout in:
# https://github.com/openSUSE/open-build-service/wiki/Feature-Toggles#steps-for-rolling-out

namespace :rollout do
  desc 'Move all the users to rollout program'
  task all_on: :environment do
    User.all_without_nobody
        .where(in_rollout: false).in_batches.update_all(in_rollout: true)
  end

  desc 'Move all the users out of the rollout program'
  task all_off: :environment do
    User.all_without_nobody
        .where(in_rollout: true).in_batches.update_all(in_rollout: false)
  end

  desc 'Move the users already in beta to rollout program'
  task from_beta: :environment do
    User.where(in_beta: true, in_rollout: false).in_batches.update_all(in_rollout: true)
  end

  desc 'Move the users with recent activity to rollout program'
  task recently_logged_users: :environment do
    User.all_without_nobody
        .where(in_rollout: false, last_logged_in_at: Time.zone.today.prev_month(3)..Time.zone.today)
        .in_batches.update_all(in_rollout: true)
  end

  desc 'Move the users without recent activity to rollout program'
  task non_recently_logged_users: :environment do
    User.all_without_nobody
        .where.not(in_rollout: true).where.not(last_logged_in_at: Time.zone.today.prev_month(3)..Time.zone.today)
        .in_batches.update_all(in_rollout: true)
  end

  desc 'Move the members of groups to rollout program'
  task from_groups: :environment do
    User.where(in_rollout: false).joins(:groups_users).distinct.in_batches.update_all(in_rollout: true)
  end

  desc 'Move Staff users to rollout program'
  task staff_on: :environment do
    User.staff
        .where(in_rollout: false).in_batches.update_all(in_rollout: true)
  end

  desc 'Move Staff users out of rollout program'
  task staff_off: :environment do
    User.staff
        .where(in_rollout: true).in_batches.update_all(in_rollout: false)
  end

  desc 'Move the anonymous user to the rollout program'
  task anonymous_on: :environment do
    user = User.find_by(login: '_nobody_', in_rollout: false)
    user&.update_column(:in_rollout, true)
  end

  desc 'Move the anonymous user out of the rollout program'
  task anonymous_off: :environment do
    user = User.find_by(login: '_nobody_', in_rollout: true)
    user&.update_column(:in_rollout, false)
  end
end
# rubocop:enable Rails/SkipsModelValidations
