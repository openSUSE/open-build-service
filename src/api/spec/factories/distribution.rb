FactoryGirl.define do
  factory :distribution do
    vendor { Faker::Lorem.word }
    version "13.2"
    name { Faker::Lorem.word }
    project { Faker::Lorem.word }
    reponame { Faker::Lorem.word }
    repository "standard"
    link "http://www.opensuse.org/"
  end
end
