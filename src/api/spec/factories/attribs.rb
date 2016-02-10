FactoryGirl.define do
  factory :attrib do
    attrib_type { create(:attrib_type_with_namespace) }
  end
end
