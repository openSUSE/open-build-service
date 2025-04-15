FactoryBot.define do
  factory :report do
    reporter factory: [:user]
    reportable { association :comment_package }
    reason { Faker::Markdown.emphasis }
  end
end
