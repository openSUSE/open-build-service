FactoryBot.define do
  factory :appeal do
    decision { association :decision_cleared }
    appellant { association :confirmed_user }
    reason { 'Some random reason' }
  end
end
