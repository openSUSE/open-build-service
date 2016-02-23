FactoryGirl.define do
  factory :attrib_type do
    sequence(:name) { |n| "attribute_factory_#{n}" }

    factory :attrib_type_with_namespace do
      attrib_namespace { create(:attrib_namespace) }
    end
  end
end
