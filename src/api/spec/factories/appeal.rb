FactoryBot.define do
  factory :appeal do
    decision
    appellant { association :confirmed_user }
    reason { 'Some random reason' }
  end
end
