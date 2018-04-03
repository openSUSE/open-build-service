FactoryBot.define do
  factory :token do
    string { Faker::Lorem.characters(32) }

    factory :service_token do
      type 'Token::Service'
    end
    factory :rss_token do
      type 'Token::Rss'
    end
  end
end
