# frozen_string_literal: true

FactoryBot.define do
  factory :issue_tracker do
    name Faker::Lorem.words(5).join(' ')
    kind 'github'
    url Faker::Internet.url('example.com')
    regex '/./'
    label Faker::Lorem.word
    issues_updated Time.now
  end
end
