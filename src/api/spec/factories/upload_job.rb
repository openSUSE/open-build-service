FactoryBot.define do
  factory :upload_job, class: 'Cloud::User::UploadJob' do
    user
    job_id { rand(1_000_000_000) }
  end
end
