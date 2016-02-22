FactoryGirl.define do
  factory :attrib_type do
    sequence(:name) { |n| "attribute_factory_#{n}" }

    factory :attrib_type_with_namespace do
      attrib_namespace { create(:attrib_namespace) }
    end

    factory :attrib_type_OBS_OwnerRootProject do
      attrib_namespace { create(:attrib_namespace, name: 'OBS') }
      name 'OwnerRootProject'
    end
  end
end
