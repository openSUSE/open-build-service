FactoryBot.define do
  factory :azure_configuration, class: 'Cloud::Azure::Configuration' do
    user
    application_id { nil }
    application_key { nil }

    trait :skip_encrypt_credentials do
      after(:build) do |config|
        config.define_singleton_method(:encrypt_credentials) do
          # Do nothing...
        end
      end
    end
  end
end
