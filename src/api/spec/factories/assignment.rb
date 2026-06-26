FactoryBot.define do
  factory :assignment do
    assigner { association :confirmed_user }
    assignee { association :confirmed_user }
    package
  end
end
