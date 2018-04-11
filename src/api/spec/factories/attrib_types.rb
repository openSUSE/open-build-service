# frozen_string_literal: true

FactoryBot.define do
  factory :attrib_type do
    sequence(:name) { |n| "attribute_factory_#{n}" }
    attrib_namespace

    factory :attrib_type_with_default_value do
      after(:create) do |attrib_type, _evaluator|
        create(:attrib_default_value, attrib_type: attrib_type)
      end
    end
  end
end
