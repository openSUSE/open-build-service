FactoryBot.define do
  factory :label_template do
    name { Faker::Lorem.word.capitalize }
    color { "##{(rand * 0xffffff).to_i.to_s(16).rjust(6, '0')}" } # Random value from 0x000000 - 0xffffff
  end
end
