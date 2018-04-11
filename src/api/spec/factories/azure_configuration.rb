# frozen_string_literal: true

FactoryBot.define do
  factory :azure_configuration, class: Cloud::Azure::Configuration do
    user { create(:user) }
    application_id nil
    application_key nil
  end
end
