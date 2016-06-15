FactoryGirl.define do
  factory :bs_request do
    description Faker::Lorem.paragraph
    state "new"

    before(:create) do |request|
      request.bs_request_actions << create(:bs_request_action)

      user = create(:confirmed_user)

      request.creator   = user.login
      request.commenter = user.login

      # Monkeypatch to avoid errors caused by permission checks made
      # in user and bs_request model
      User.current = user
    end

    after(:create) { User.current = nil }
  end
end
