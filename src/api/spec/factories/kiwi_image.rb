FactoryGirl.define do
  factory :kiwi_image, class: Kiwi::Image do
    name { Faker::Name.name }
  end
end
