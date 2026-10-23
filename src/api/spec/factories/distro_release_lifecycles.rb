FactoryBot.define do
  factory :distro_release_lifecycle do
    sequence(:name) { |n| "distro_release_lifecycle_#{n}" }
    date { Date.current }
    status { :general_availability }
    distro_release
  end
end
