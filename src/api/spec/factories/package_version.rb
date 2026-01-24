FactoryBot.define do
  factory :package_version_local do
    package
    sequence(:version) { |n| "2.12.#{n}" }
    type { 'PackageVersionLocal' }
  end
end
