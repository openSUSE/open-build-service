FactoryBot.define do
  factory :status_report, class: 'Status::Report' do
    checkable { association :repository }
    uuid { SecureRandom.hex(8) }
  end
end
