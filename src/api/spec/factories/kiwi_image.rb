FactoryBot.define do
  factory :kiwi_image, class: Kiwi::Image do
    name { Faker::Name.name }
    md5_last_revision nil
    association :preference, factory: :kiwi_preference

    factory :kiwi_image_with_package do
      transient do
        package_name 'package_with_kiwi_image'
        with_kiwi_file false
        kiwi_file_name { "#{package_name}.kiwi" }
        file_content { Kiwi::Image::DEFAULT_KIWI_BODY }
        project nil
      end

      after(:create) do |image, evaluator|
        if evaluator.with_kiwi_file
          image.package =
            create(:package_with_kiwi_file, name: evaluator.package_name, project: evaluator.project,
                   kiwi_file_content: evaluator.file_content, kiwi_file_name: evaluator.kiwi_file_name)
          image.md5_last_revision = image.package.kiwi_file_md5
        else
          image.package = create(:package, name: evaluator.package_name, project: evaluator.project)
        end
        image.save
      end
    end
  end
end
