FactoryGirl.define do
  factory :relationship do
    project
    user
    role { Role.find_by_title('maintainer') }
  end
end
