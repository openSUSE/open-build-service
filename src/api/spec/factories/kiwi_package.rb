FactoryBot.define do
  factory :kiwi_package, class: 'Kiwi::Package' do
    transient do
      image { association :kiwi_image }
    end

    package_group { association :kiwi_package_group, image: image }

    name        { Faker::Creature::Cat.name }
    arch        { Faker::Creature::Cat.name }
    replaces    { Faker::Creature::Cat.name }
    bootinclude { Faker::Boolean.boolean(true_ratio: 0.4) }
    bootdelete  { Faker::Boolean.boolean(true_ratio: 0.2) }
  end
end
