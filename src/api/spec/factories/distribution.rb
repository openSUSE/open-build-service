# frozen_string_literal: true

FactoryBot.define do
  factory :distribution do
    vendor { Faker::Lorem.word }
    version '13.2'
    name { Faker::Lorem.word }
    project { Faker::Lorem.word }
    sequence(:reponame) { |n| "reponame_#{n}" }
    repository 'standard'
    link 'http://www.opensuse.org/'

    transient do
      architectures []
    end

    after(:create) do |distribution, evaluator|
      evaluator.architectures.each do |arch|
        distribution.architectures << Architecture.find_or_create_by!(name: arch)
      end
    end
  end
end
