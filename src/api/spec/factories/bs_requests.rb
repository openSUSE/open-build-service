FactoryGirl.define do
  factory :bs_request do
    description { Faker::Lorem.paragraph }
    state "new"

    before(:create) do |request|
      unless request.creator
        user = create(:confirmed_user)

        request.creator   = user.login
        request.commenter = user.login
      end
      unless request.bs_request_actions.any?
        request.bs_request_actions << create(:bs_request_action)
      end
      # Monkeypatch to avoid errors caused by permission checks made
      # in user and bs_request model
      User.current = User.find_by(login: request.creator) || user
    end

    after(:create) { User.current = nil }
  end
end
