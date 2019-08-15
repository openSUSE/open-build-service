FactoryBot.define do
  factory :issue_tracker do
    name { 'gh' }
    description { Faker::Lorem.paragraph }
    kind { 'github' }
    url { Faker::Internet.url(host: 'example.com') }
    show_url { Faker::Internet.url(host: 'example.com') }
    regex { 'gh#(\d+)' }
    label { 'gh#@@@' }
    issues_updated { Time.now }
  end
end
