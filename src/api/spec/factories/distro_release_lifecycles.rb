FactoryBot.define do
  factory :distro_release_lifecycle do
    sequence(:name) { |n| "phase_#{n}" }
    date { Time.zone.today }
    status { :general_availability }
    distro_release
  end
end
