FactoryBot.define do
  factory :review do
    state { :new }

    factory :user_review do
      by_user { create(:user) }
    end

    factory :accepted_review do
      state { :accepted }
    end
  end
end
