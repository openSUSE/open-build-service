FactoryBot.define do
  factory :package_version_upstream do
    package
    type { 'PackageVersionUpstream' }
    version { Faker::App.version }
  end
end
