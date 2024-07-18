FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    realname { Faker::Name.first_name }
    sequence(:login) { |n| "user_#{n}" }
    password { 'buildservice' }

    transient do
      create_home_project { false }
    end

    trait :in_beta do
      in_beta { true }
    end

    trait :in_rollout do
      in_rollout { true }
    end

    trait :with_home do
      create_home_project { true }
    end

    to_create do |user, evaluator|
      if evaluator.create_home_project
        user.save!
      else
        # rubocop:disable Rails/SkipsModelValidations
        # Avoid triggering the callbacks to propagate the change to the backend
        Configuration.update_column(:allow_user_to_create_home_project, false)
        # But invalidate the cache
        Configuration.invalidate_cache
        user.save!
        Configuration.update_column(:allow_user_to_create_home_project, true)
        Configuration.invalidate_cache
        # rubocop:enable Rails/SkipsModelValidations
      end
    end

    factory :confirmed_user do
      state { 'confirmed' }

      factory :admin_user do
        roles { [Role.find_by_title('admin')] }
      end

      factory :staff_user do
        roles { [Role.find_by_title('Staff')] }
      end

      factory :moderator do
        roles { [Role.find_by_title('Moderator')] }
      end

      factory :user_with_groups do
        after(:create) do |user|
          create(:group, users: [user])
        end
      end

      factory :user_with_service_token do
        after(:create) do |user|
          create(:service_token, executor: user)
        end
      end
      factory :dead_user do
        after(:create) do |user|
          user.created_at = 5.months.ago
          user.last_logged_in_at = 4.months.ago
          user.save!(validate: false)
        end
      end
    end

    factory :user_deprecated_password do
      after(:create) do |user|
        user.password_digest = nil
        user.deprecated_password = 'b6ead59da72f491dd29f84a6579d6dc4' # password: buildservice
        user.deprecated_password_hash_type = 'md5'
        user.deprecated_password_salt = 'm/YVlu5w0M'

        # ignore validations because `password_digest` can't be nil
        user.save!(validate: false)
      end
    end

    factory :deleted_user do
      login { 'deleted' }
      state { 'deleted' }
    end

    factory :locked_user do
      state { 'locked' }
    end

    factory :user_nobody do
      login { '_nobody_' }
    end

    # This is needed because the salt is random
    # in User.after_validation
    after(:create) do |user|
      user.password = 'buildservice'
      user.save!
    end
  end
end
