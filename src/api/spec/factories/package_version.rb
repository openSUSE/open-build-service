FactoryBot.define do
  factory :package_version_upstream do
    package
    type { 'PackageVersionUpstream' }
    version { Faker::App.version }
  end

  factory :package_version_local do
    package
    type { 'PackageVersionLocal' }
    version { Faker::App.version }
  end
end
