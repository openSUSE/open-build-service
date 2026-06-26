FactoryBot.define do
  factory :label_template_global do
    name { Faker::Lorem.word.capitalize }
    color { set_random_color }
  end
end
