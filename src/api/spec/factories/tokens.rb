FactoryBot.define do
  factory :token do
    string { Faker::Lorem.characters(number: 32) }
    user

    factory :service_token, class: 'Token::Service' do
      package
      object_to_authorize { package }
      type { 'Token::Service' }
    end

    factory :rss_token, class: 'Token::Rss' do
      package
      object_to_authorize { package }
      type { 'Token::Rss' }
    end

    factory :rebuild_token, class: 'Token::Rebuild' do
      package
      object_to_authorize { package }
      type { 'Token::Rebuild' }
    end

    factory :release_token, class: 'Token::Release' do
      package
      object_to_authorize { package }
      type { 'Token::Release' }
    end

    factory :workflow_token, class: 'Token::Workflow' do
      type { 'Token::Workflow' }
      scm_token { Faker::Lorem.characters(number: 32) }
    end
  end
end
