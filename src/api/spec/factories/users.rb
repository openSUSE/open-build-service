FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    realname { Faker::Name.name }
    sequence(:login) { |n| "user_#{n}" }
    password 'buildservice'

    factory :confirmed_user do
      state 2

      factory :admin_user do
        roles { [Role.find_by_title('admin')] }
      end

      factory :staff_user do
        roles { [Role.find_by_title('Staff')] }
      end

      factory :user_with_groups do
        after(:create) do |user|
          create(:group, users: [user])
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
      login 'deleted'
      state 4
    end

    factory :user_nobody do
      login '_nobody_'
    end

    # This is needed because the salt is random
    # in User.after_validation
    after(:create) do |user|
      user.password = 'buildservice'
      user.save!
    end
  end
end
