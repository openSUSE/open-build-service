FactoryBot.define do
  factory :ec2_configuration, class: Cloud::Ec2::Configuration do
    user
    arn { "arn:#{Faker::Lorem.characters(number: 10)}" }
    external_id { Faker::Lorem.characters(number: 24) }
  end
end
