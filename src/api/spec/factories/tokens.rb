FactoryBot.define do
  factory :token do
    string { Faker::Lorem.characters(32) }

    factory :service_token, class: Token::Service do
      type 'Token::Service'
    end
    factory :rss_token, class: Token::Rss do
      type 'Token::Rss'
    end
  end
end
