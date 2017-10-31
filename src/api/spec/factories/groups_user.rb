FactoryBot.define do
  factory :groups_user do
    user { create(:user) }
    group { create(:group) }
  end
end
