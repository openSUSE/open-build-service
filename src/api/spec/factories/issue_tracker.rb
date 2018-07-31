FactoryBot.define do
  factory :issue_tracker do
    name 'gh'
    description { Faker::Lorem.paragraph }
    kind 'github'
    url { Faker::Internet.url('example.com') }
    show_url { Faker::Internet.url('example.com') }
    regex 'gh#(\d+)'
    label { Faker::Lorem.word }
    issues_updated { Time.now }
  end
end
