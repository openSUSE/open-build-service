FactoryBot.define do
  factory :review do
    state { :new }

    factory :user_review do
      by_user { association :user }
    end
  end
end
