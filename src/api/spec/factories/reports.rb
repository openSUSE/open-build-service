FactoryBot.define do
  factory :report do
    user
    reporter { user }
    reportable { association :comment_package }
    reason { Faker::Markdown.emphasis }
  end
end
