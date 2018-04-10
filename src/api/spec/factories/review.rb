# frozen_string_literal: true
FactoryBot.define do
  factory :review do
    state :new

    factory :user_review do
      by_user { create(:user) }
    end
  end
end
