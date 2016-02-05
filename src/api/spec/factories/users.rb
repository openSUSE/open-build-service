FactoryGirl.define do
  factory :user do
    email { Faker::Internet.email }
    realname { Faker::Name.name }
    login { Faker::Internet.user_name(nil, %w(_)) }
    password 'buildservice'

    factory :confirmed_user do
      state 2

      factory :admin_user do
        roles { [Role.find_by_title('admin')] }
      end
    end

    # This is needed because the salt is random
    # in User.after_validation
    after(:create) do |user|
      user.update_password('buildservice')
      user.save!
    end
  end
end
