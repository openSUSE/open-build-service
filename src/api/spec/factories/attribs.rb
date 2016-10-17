FactoryGirl.define do
  factory :attrib do
    attrib_type { create(:attrib_type_with_namespace) }

    factory :maintained_attrib do
      attrib_type AttribType.find_by_namespace_and_name!('OBS', 'Maintained')
    end
  end
end
