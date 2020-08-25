FactoryBot.define do
  factory :bs_request do
    # Monkeypatch how we create BsRequests to avoid errors caused by permission checks
    # made in BsRequestPermissionCheck that depend on a logged in user.
    to_create do |instance|
      creator = User.find_by!(login: instance.creator)
      creator.run_as do
        instance.save!
      end
    end

    description { Faker::Lorem.paragraph }
    commenter do
      creator
    end
    creator do
      create(:confirmed_user)
    end

    reviews do |evaluator|
      ret = []
      ret << build(:review, by_project: evaluator.review_by_project) if evaluator.review_by_project
      ret << build(:review, by_group: evaluator.review_by_group) if evaluator.review_by_group
      ret << build(:review, by_user: evaluator.review_by_user) if evaluator.review_by_user
      if evaluator.review_by_package
        ret << build(:review, by_package: evaluator.review_by_package.name,
                              by_project: evaluator.review_by_package.project.name)
      end
      ret
    end

    bs_request_actions do |evaluator|
      attribs = attributes_for(:bs_request_action,
                               type: evaluator.type,
                               source_project: evaluator.source_project,
                               source_package: evaluator.source_package,
                               source_rev: evaluator.source_rev,
                               target_project: evaluator.target_project,
                               target_package: evaluator.target_package,
                               target_repository: evaluator.target_repository,
                               target_releaseproject: evaluator.target_releaseproject,
                               role: evaluator.role,
                               group_name: evaluator.group_name,
                               person_name: evaluator.person_name)

      attribs[:source_project] = attribs[:source_project].name if attribs[:source_project].is_a?(Project)

      attribs[:target_project] = attribs[:target_project].name if attribs[:target_project].is_a?(Project)

      if attribs[:source_package].is_a?(Package)
        attribs[:source_project] ||= attribs[:source_package].project.name
        attribs[:source_package] = attribs[:source_package].name
      end
      if attribs[:target_package].is_a?(Package)
        attribs[:target_project] ||= attribs[:target_package].project.name
        attribs[:target_package] = attribs[:target_package].name
      end
      # TODO: this should really be .to_sym but the submit action validates the source
      attribs[:type] = attribs[:type].to_s

      [build(:bs_request_action, attribs)]
    end

    before(:create) do |_request, evaluator|
      raise 'Do not pass a string as creator' if evaluator.creator.is_a?(String)
    end

    after(:create) do |request, evaluator|
      next unless request.staging_project && evaluator.staging_owner

      evaluator.staging_owner.run_as do
        request.bs_request_actions.where(type: :submit).each do |action|
          BranchPackage.new(
            project: action.source_project,
            package: action.source_package,
            target_project: request.staging_project.name,
            target_package: action.target_package
          ).branch
        end
      end
    end

    transient do
      type { nil }
      source_project { nil }
      source_package { nil }
      source_rev { nil }
      target_project { nil }
      target_package { nil }
      target_repository { nil }
      target_releaseproject { nil }
      group_name { nil }
      person_name { nil }
      role { nil }
      reviewer { nil }
      review_by_user { nil }
      review_by_group { nil }
      review_by_project { nil }
      review_by_package { nil }
      staging_owner { nil }
      creating_user do |evaluator|
        evaluator.creator.is_a?(User) ? evaluator.creator : User.find_by_login(evaluator.creator)
      end
    end

    after(:build) do |request|
      request[:state] ||= 'new'
    end

    after(:create) do |request, evaluator|
      # the state will be overwritten by the constructor, so we need
      # to set it afterwards
      state = evaluator.state
      state ||= :review if evaluator.reviews.present?
      if state
        request.update(state: state)
        request.reload
      end
    end

    factory :bs_request_with_submit_action do
      type { :submit }

      factory :declined_bs_request do
        state { :declined }
      end
    end

    factory :delete_bs_request do
      type { :delete }
    end

    factory :add_role_request do
      type { :add_role }
      person_name { |evaluator| evaluator.creator.login }

      factory :add_maintainer_request do
        transient do
          role { Role.find_by_title('maintainer') }
        end
      end
    end

    factory :set_bugowner_request do
      type { :set_bugowner }
      transient do
        person_name do
          creating_user.login
        end
        target_project do
          creating_user.home_project
        end
      end
    end

    factory :bs_request_with_maintenance_release_action do
      type { :maintenance_release }
    end

    factory :bs_request_with_maintenance_incident_action do
      type { :maintenance_incident }
    end

    factory :superseded_bs_request, parent: :set_bugowner_request do
      transient do
        superseded_by_request { nil }
      end

      after(:create) do |request, evaluator|
        request.update(state: :superseded, superseded_by: evaluator.superseded_by_request.number)
      end
    end
  end
end
