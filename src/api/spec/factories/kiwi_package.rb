# frozen_string_literal: true
FactoryBot.define do
  factory :kiwi_package, class: Kiwi::Package do
    transient do
      image { create(:kiwi_image) }
    end

    package_group { create(:kiwi_package_group, image: image) }

    name        { Faker::Cat.name }
    arch        { Faker::Cat.name }
    replaces    { Faker::Cat.name }
    bootinclude { Faker::Boolean.boolean(0.4) }
    bootdelete  { Faker::Boolean.boolean(0.2) }
  end
end
