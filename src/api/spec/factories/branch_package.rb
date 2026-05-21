# FIXME: This factory is a wrapper around BranchPackage.new when you can just call BranchPackae.new wherever you `create(:branch_package)`. It makes no sense...
FactoryBot.define do
  factory :branch_package_base, class: 'BranchPackage' do
    initialize_with { new(**attributes) }

    # BranchPackage is a PORO (Plain Old Ruby Object). Override FactoryBot `create` method
    skip_create

    factory :branch_package do
      initialize_with { new(**attributes).branch }
    end
  end
end
