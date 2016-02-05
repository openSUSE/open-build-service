FactoryGirl.define do
  factory :project do
    name Faker::Internet.domain_word
    title Faker::Book.title

    # remote projects validate additional the description and remoteurl
    factory :remote_project do
      description Faker::Lorem.sentence
      remoteurl Faker::Internet.url
    end
  end
end
