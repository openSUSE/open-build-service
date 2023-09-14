FactoryBot.define do
  factory :report do
    user
    reportable { association :comment_package }
  end
end
