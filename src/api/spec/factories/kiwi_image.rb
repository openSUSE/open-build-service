FactoryGirl.define do
  factory :kiwi_image, class: Kiwi::Image do
    name { Faker::Name.name }
    md5_last_revision { Faker::Crypto.md5 }
  end
end
