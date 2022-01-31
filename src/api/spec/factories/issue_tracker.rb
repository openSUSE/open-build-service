FactoryBot.define do
  factory :issue_tracker do
    name { 'example' }
    description { Faker::Lorem.paragraph }
    kind { 'github' }
    url { Faker::Internet.url(host: 'example.com') }
    show_url { Faker::Internet.url(host: 'example.com') }
    regex { '\bexample#(\d+)\b' }
    label { 'example#@@@' }
    issues_updated { Time.now }
  end
end
