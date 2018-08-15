FactoryBot.define do
  factory :kiwi_description, class: Kiwi::Description do
    association :image, factory: :kiwi_image

    description_type { Kiwi::Description.description_types.keys.first }
    author { 'example_author' }
    contact { 'example_contact' }
    specification { 'example_specification' }
  end
end
