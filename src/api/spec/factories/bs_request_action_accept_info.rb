# frozen_string_literal: true

FactoryBot.define do
  factory :bs_request_action_accept_info do
    factory :bs_request_action_accept_info_with_action do
      rev { Faker::Number.hexadecimal(10) }
      srcmd5 { Faker::Number.hexadecimal(10) }
      xsrcmd5 { Faker::Number.hexadecimal(10) }
      osrcmd5 { Faker::Number.hexadecimal(10) }
      oxsrcmd5 { Faker::Number.hexadecimal(10) }
      oproject { Faker::Lorem.word }
      opackage { Faker::Lorem.word }
      bs_request_action
    end
  end
end
