FactoryBot.define do
  factory :label_template do
    name { Faker::Lorem.word.capitalize }
    color { set_random_color }
  end
end
