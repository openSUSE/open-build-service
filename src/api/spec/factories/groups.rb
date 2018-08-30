FactoryBot.define do
  factory :group do
    sequence(:title) { |n| "group_#{n}" }
    email { Faker::Internet.email }

    factory :group_with_user do
      after(:create) do |group|
        group.groups_users.create(user: create(:confirmed_user))
      end
    end
  end
end
