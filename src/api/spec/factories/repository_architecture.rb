# frozen_string_literal: true
FactoryBot.define do
  factory :repository_architecture do
    repository
    architecture
    before(:create) do |repository_architecture|
      repository_architecture.position = repository_architecture.repository.repository_architectures.count
    end
  end
end
