FactoryBot.define do
  factory :report do
    user
    reportable { association :comment_package }
    reason { Faker::Markdown.emphasis }
  end
end
