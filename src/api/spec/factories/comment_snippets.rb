FactoryBot.define do
  factory :comment_snippet do
    title { Faker::Lorem.sentence(word_count: 3) }
    body { Faker::Lorem.paragraph }
    user
  end
end
