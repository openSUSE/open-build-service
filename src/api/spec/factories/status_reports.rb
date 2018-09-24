FactoryBot.define do
  factory :status_report, class: Status::Report do
    checkable { create(:repository) }
    uuid { SecureRandom.hex(8) }
  end
end
