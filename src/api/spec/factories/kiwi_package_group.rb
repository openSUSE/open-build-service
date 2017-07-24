FactoryGirl.define do
  factory :kiwi_package_group, class: Kiwi::PackageGroup do
    association :image, factory: :kiwi_image

    kiwi_type { Kiwi::PackageGroup.kiwi_types.keys[Faker::Number.between(0, Kiwi::PackageGroup.kiwi_types.keys.length - 1)] }
    profiles { Faker::Cat.name }
    pattern_type { Faker::Cat.name }
  end
end
