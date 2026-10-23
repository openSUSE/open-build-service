FactoryBot.define do
  factory :distro_release_lifecycle do
    sequence(:name) { |n| "lifecycle_#{n}" }
    date { Time.zone.today }
    status { :planned }
    distro_release
  end
end
