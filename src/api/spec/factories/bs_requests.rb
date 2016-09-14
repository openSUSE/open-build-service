FactoryGirl.define do
  factory :bs_request do
    description { Faker::Lorem.paragraph }
    state "new"

    transient do
      type nil
      source_project nil
    end

    before(:create) do |request, evaluator|
      unless request.creator
        user = create(:confirmed_user)

        request.creator   = user.login
        request.commenter = user.login
      end
      if request.bs_request_actions.none?
        request.bs_request_actions << create(:bs_request_action, type: evaluator.type, source_project: evaluator.source_project)
      end
      # Monkeypatch to avoid errors caused by permission checks made
      # in user and bs_request model
      User.current = User.find_by(login: request.creator) || user
    end

    after(:create) { User.current = nil }
  end
end
