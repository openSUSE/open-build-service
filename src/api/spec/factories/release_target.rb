# frozen_string_literal: true

FactoryBot.define do
  factory :release_target do
    repository
    target_repository { create(:repository) }
  end
end
