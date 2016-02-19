FactoryGirl.define do
  factory :groups_user do
    user
    group
    email { 1 }
  end
end
