FactoryBot.define do
  factory :bs_request do
    description { Faker::Lorem.paragraph }
    state { 'new' }

    transient do
      type { nil }
      source_project { nil }
      source_package { nil }
      target_project { nil }
      target_package { nil }
      target_repository { nil }
      reviewer { nil }
      request_state { 'review' }
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

    factory :bs_request_with_submit_action do
      after(:create) do |request, evaluator|
        request.bs_request_actions.delete_all
        request.bs_request_actions << create(
          :bs_request_action_submit,
          target_project: evaluator.target_project,
          target_package: evaluator.target_package,
          source_project: evaluator.source_project,
          source_package: evaluator.source_package
        )
      end
    end

    factory :declined_bs_request do
      after(:create) do |request, evaluator|
        request.bs_request_actions.delete_all
        request.bs_request_actions << create(
          :bs_request_action_submit,
          target_project: evaluator.target_project,
          target_package: evaluator.target_package,
          source_project: evaluator.source_project,
          source_package: evaluator.source_package
        )
        request.state = 'declined'
        request.save!
      end
    end

    factory :review_bs_request do
      after(:create) do |request, evaluator|
        request.bs_request_actions.delete_all
        request.bs_request_actions << create(
          :bs_request_action_submit,
          target_project: evaluator.target_project,
          target_package: evaluator.target_package,
          source_project: evaluator.source_project,
          source_package: evaluator.source_package
        )
        request.reviews << Review.new(by_user: evaluator.reviewer)
        request.state = 'review'
        request.save!
      end
    end

    factory :review_bs_request_by_group do
      after(:create) do |request, evaluator|
        request.bs_request_actions.delete_all
        request.bs_request_actions << create(
          :bs_request_action_submit,
          target_project: evaluator.target_project,
          target_package: evaluator.target_package,
          source_project: evaluator.source_project,
          source_package: evaluator.source_package
        )
        request.reviews << Review.new(by_group: evaluator.reviewer)
        request.state = evaluator.request_state
        request.save!
      end
    end

    factory :delete_bs_request do
      after(:create) do |request, evaluator|
        request.bs_request_actions.delete_all
        request.bs_request_actions << create(
          :bs_request_action_delete,
          target_project: evaluator.target_project,
          target_package: evaluator.target_package,
          target_repository: evaluator.target_repository
        )
      end
    end

    factory :bs_request_with_maintenance_release_action do
      after(:create) do |request, evaluator|
        request.bs_request_actions.delete_all
        request.bs_request_actions << create(
          :bs_request_action_maintenance_release,
          target_project: evaluator.target_project,
          target_package: evaluator.target_package,
          source_project: evaluator.source_project,
          source_package: evaluator.source_package
        )
      end
    end

    factory :bs_request_with_maintenance_incident_action do
      after(:create) do |request, evaluator|
        request.bs_request_actions.delete_all
        request.bs_request_actions << create(
          :bs_request_action_maintenance_incident,
          target_project: evaluator.target_project,
          target_package: evaluator.target_package,
          source_project: evaluator.source_project,
          source_package: evaluator.source_package
        )
      end
    end
  end
end
