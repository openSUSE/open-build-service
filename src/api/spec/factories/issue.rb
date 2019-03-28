FactoryBot.define do
  factory :issue do
    name { Faker::Base.numerify('##-####') }

    factory :issue_with_tracker do
      issue_tracker
    end
  end
end
