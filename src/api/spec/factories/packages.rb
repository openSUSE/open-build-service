FactoryGirl.define do
  factory :package do
    project
    sequence(:name) { |n| "package_#{n}" }

    after(:create) do |package|
      # NOTE: Enable global write through when writing new VCR cassetes.
      # ensure the backend knows the project
      if CONFIG['global_write_through']
        Suse::Backend.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/_meta", package.to_axml)
      end
    end

    factory :package_with_file do
      after(:create) do |package|
        # NOTE: Enable global write through when writing new VCR cassetes.
        # ensure the backend knows the project
        if CONFIG['global_write_through']
          Suse::Backend.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/_config", Faker::Lorem.paragraph)
          Suse::Backend.put("/source/#{CGI.escape(package.project.name)}/#{CGI.escape(package.name)}/somefile.txt", Faker::Lorem.paragraph)
        end
      end
    end

    factory :package_with_service do
      after(:create) do |package|
        # NOTE: Enable global write through when writing new VCR cassetes.
        # ensure the backend knows the project
        Suse::Backend.put("/source/#{URI.escape(package.project.name)}/#{URI.escape(package.name)}/_service", '<service/>')
      end
    end

    factory :package_with_failed_comment_attribute do
      after(:create) do |package|
        attribute_type = AttribType.find_by_name("OBS:ProjectStatusPackageFailComment")
        attrib = build(:attrib, attrib_type: attribute_type, package: package)
        attrib.values << build(:attrib_value, value: Faker::Lorem.sentence)
        attrib.save!
      end
    end
  end
end
