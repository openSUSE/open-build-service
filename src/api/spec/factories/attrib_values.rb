FactoryGirl.define do
  factory :attrib_value do
    transient do
      position 1
      attrib_type { create(:attrib_type) }
      attrib_default_value { create(:attrib_default_value) }
      project { create(:project) }
      default_value Faker::Lorem.word
    end

    attrib { create(:attrib) }

    before(:create) do |attrib_value, evaluator|
      attrib_value.attrib.attrib_type = evaluator.attrib_type
      attrib_value.attrib.project = evaluator.project

      attrib_value.attrib.attrib_type = evaluator.attrib_default_value.attrib_type
      attrib_value.attrib.save!

      evaluator.attrib_default_value.value = evaluator.default_value
      attrib_value.attrib.attrib_type.default_values << evaluator.attrib_default_value
    end

    # this is necessary! otherwise the default value will not be recognized.
    after(:create, &:reload)
  end
end
