FactoryBot.define do
  factory :distro_release_lifecycle do
    sequence(:name) { |n| "Lifecycle #{n}" }
    date { Time.zone.today }
    status { :planned }
    distro_release
  end
end
