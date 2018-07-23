FactoryBot.define do
  factory :issue_tracker do
    name Faker::Lorem.words(5).join(' ')
    description Faker::Lorem.paragraph
    kind 'github'
    url Faker::Internet.url('example.com')
    show_url Faker::Internet.url('example.com')
    regex '/./'
    label Faker::Lorem.word
    issues_updated Time.now
  end
end
