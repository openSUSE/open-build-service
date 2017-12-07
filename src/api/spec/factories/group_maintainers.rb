FactoryBot.define do
  factory :group_maintainer do
    user { create(:user) }
    group { create(:group) }
  end
end
