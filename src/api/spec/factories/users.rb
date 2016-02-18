FactoryGirl.define do
  factory :user do
    email { Faker::Internet.email }
    realname { Faker::Name.name }
    sequence(:login){|n| "#{Faker::Internet.user_name(nil, %w(_))}#{n}" }
    password 'buildservice'

    factory :confirmed_user do
      state 2

      factory :admin_user do
        roles { [Role.find_by_title('admin')] }
      end
    end

    factory :deleted_user do
      login 'deleted'
      state 4
    end

    # This is needed because the salt is random
    # in User.after_validation
    after(:create) do |user|
      user.update_password('buildservice')
      user.save!
    end
  end
end
