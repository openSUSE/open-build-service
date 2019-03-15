FactoryBot.define do
  factory :attrib_namespace do
    name { Faker::Lorem.unique.word }
  end
end
