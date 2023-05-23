FactoryBot.define do
  factory :branch_package do
    initialize_with { new(**attributes) }

    # BranchPackage is a PORO (Plain Old Ruby Object). Override FactoryBot `create` method
    skip_create
  end
end
