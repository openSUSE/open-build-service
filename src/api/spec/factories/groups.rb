FactoryBot.define do
  factory :group do
    sequence(:title) { |n| "group_#{n}" }
    email { Faker::Internet.email }

    factory :group_with_user do
      transient do
        user { create(:confirmed_user) }
      end

      after(:create) do |group, evaluator|
        group.groups_users.create(user: evaluator.user)
      end
    end
  end
end
