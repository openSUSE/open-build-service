FactoryGirl.define do
  factory :kiwi_image, class: Kiwi::Image do
    name { Faker::Name.name }
    md5_last_revision { Faker::Crypto.md5 }

    factory :kiwi_image_with_package do
      transient do
        package_name { 'package_with_kiwi_image' }
      end

      after(:create) do |image, evaluator|
        image.package = create(:package, name: evaluator.package_name)
        image.save
      end
    end
  end
end
