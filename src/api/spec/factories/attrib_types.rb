FactoryGirl.define do
  factory :attrib_type do
    sequence(:name) { |n| "attribute_factory_#{n}" }
    attrib_namespace
  end
end
