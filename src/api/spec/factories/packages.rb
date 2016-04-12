FactoryGirl.define do
  factory :package do
    sequence(:name) { |n| "#{Faker::Internet.domain_word}#{n}" }
    factory :package_with_file do
      after(:create) do |package|
        Suse::Backend.put("/source/#{package.project.name}/#{package.name}/somefile.txt", Faker::Lorem.paragraph)
      end
    end
  end
end
