FactoryBot.define do
  factory :distribution do
    vendor { Faker::Lorem.word }
    version { '13.2' }
    name { Faker::Lorem.word }
    project { Faker::Lorem.word }
    sequence(:reponame) { |n| "reponame_#{n}" }
    repository { 'standard' }
    link { 'http://www.opensuse.org/' }

    transient do
      architectures { ['x86_64', 'ppc64le'] }
      icons_count { 2 }
    end

    after(:create) do |distribution, evaluator|
      evaluator.architectures.each do |arch|
        distribution.architectures << Architecture.find_by!(name: arch)
      end
      create_list(:distribution_icon, evaluator.icons_count, distributions: [distribution])
    end
  end

  factory :distribution_icon do
    width { 64 }
    height { 64 }
    url { 'https://static.opensuse.org/distributions/logos/opensuse.png' }
  end
end
