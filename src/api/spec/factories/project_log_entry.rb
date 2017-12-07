FactoryBot.define do
  factory :project_log_entry do
    project
    datetime { Time.zone.today }
    event_type 'commit'
  end
end
