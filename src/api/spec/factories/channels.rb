FactoryBot.define do
  factory :channel do
    package
  end

  factory :channel_binary_list do
    channel
    repository
    project
    architecture
  end

  factory :channel_binary do
    sequence(:name) { |n| "channel_binary_#{n}" }
    project
    architecture
    repository
    channel_binary_list
    sequence(:package) { |n| "channel_package_binary_#{n}" }
  end
end
