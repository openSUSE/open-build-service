FactoryBot.define do
  factory :attrib_default_value do
    attrib_type
    position { 1 }
    value { Faker::Lorem.word }
  end
end
