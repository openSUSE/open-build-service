FactoryBot.define do
  factory :notification_payload, class: Hash do
    initialize_with { attributes.with_indifferent_access }
    skip_create
    repository { Faker::Lorem.word }
    name { Faker::Lorem.word }
    version { Faker::App.semantic_version }
    release { Faker::App.semantic_version }
    binaryarch { Architecture.limit(1).order('RAND()').first.name }
    disturl { "obs://build.opensuse.org/#{Faker::Lorem.word}/#{Faker::Lorem.word}/#{Faker::Crypto.sha1}-#{name}" }
    buildtime { Faker::Time.between(from: 1.year.ago, to: 1.week.ago).to_i }
    supportstatus { 'l3' }
    binaryid { Faker::Crypto.sha1 }
    project { Faker::Lorem.word }
    package { Faker::Lorem.word }
    updateinfoid { 'openSUSE-2024-12345' }
    updateinfoversion { rand(10) }
    patchinforef { nil }
    medium { nil }
    ismedium { nil }

    trait :medium do
      name { "some-image.x86_64-#{Faker::App.semantic_version}-Build#{Faker::App.semantic_version}.docker.tar" }
      ismedium { name }
    end

    trait :with_patchinfo do
      patchinforef { 'openSUSE:Maintenance:12345/patchinfo' }
    end
  end
end
