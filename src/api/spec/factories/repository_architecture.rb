FactoryBot.define do
  factory :repository_architecture do
    repository
    architecture
    after(:create, &:move_to_bottom)
  end
end
