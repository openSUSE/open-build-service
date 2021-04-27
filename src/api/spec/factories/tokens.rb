FactoryBot.define do
  factory :token do
    string { Faker::Lorem.characters(number: 32) }
    user
    package

    trait :with_package_from_association_or_params do
      package_from_association_or_params { package }
      project_from_association_or_params { package.project }
    end

    factory :service_token, class: 'Token::Service' do
      type { 'Token::Service' }
    end

    factory :rss_token, class: 'Token::Rss' do
      type { 'Token::Rss' }
    end

    factory :rebuild_token, class: 'Token::Rebuild' do
      type { 'Token::Rebuild' }
    end

    factory :release_token, class: 'Token::Release' do
      type { 'Token::Release' }
    end
  end
end
