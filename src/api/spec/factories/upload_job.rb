# frozen_string_literal: true

FactoryBot.define do
  factory :upload_job, class: Cloud::User::UploadJob do
    user
    job_id { Faker::Number.between(100, 1000) }
  end
end
