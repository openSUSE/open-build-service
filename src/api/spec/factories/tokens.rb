FactoryBot.define do
  factory :token do
    string { Faker::Lorem.characters(32) }

    factory :service_token, class: Token::Service
    factory :rss_token, class: Token::Rss
  end
end
