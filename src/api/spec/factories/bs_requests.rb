FactoryGirl.define do
  factory :bs_request do
    description Faker::Lorem.paragraph
    state "new"
    bs_request_actions { [create(:bs_request_action)] }

    before(:create) do |request|
      unless request.creator
        user = create(:confirmed_user)

        request.creator   = user.login
        request.commenter = user.login
      end

      # Monkeypatch to avoid errors caused by permission checks made
      # in user and bs_request model
      User.current = user unless request.creator
      User.current = User.find_by(login: request.creator) if request.creator
    end

    after(:create) { User.current = nil }
  end
end
