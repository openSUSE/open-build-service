FactoryBot.define do
  factory :workflow_run do
    token { association :workflow_token }
    status { 'running' }
    scm_vendor { 'github' }
    hook_event { 'pull_request' }
    hook_action { 'opened' }
    event_source_name { '1' }
    generic_event_type { 'pull_request' }
    repository_name { Faker::Lorem.word }
    repository_owner { Faker::Team.creature }
    response_url { 'https://api.github.com' }
    workflow_configuration_path { '.obs/workflows.yml' }
    workflow_configuration_url { nil }
    request_headers do
      <<~END_OF_HEADERS
        HTTP_X_GITHUB_EVENT: pull_request
        HTTP_X_GITHUB_HOOK_ID: 12345
        HTTP_X_GITHUB_DELIVERY: b4a6d950-110b-11ee-9095-943f7b2ddd1c
      END_OF_HEADERS
    end
    request_payload do
      File.read('spec/fixtures/files/request_payload_github_pull_request_opened.json')
    end
    workflow_configuration do
      File.read('spec/fixtures/files/workflows.yml')
    end

    trait :with_url do
      workflow_configuration_path { nil }
      workflow_configuration_url { 'http://example.com/workflows.yml' }
    end

    # Emulating the old workflow runs, before we started to store them
    trait :without_configuration_data do
      workflow_configuration_path { nil }
      workflow_configuration_url { nil }
      workflow_configuration { nil }
    end

    trait :pull_request_closed do
      hook_action { 'closed' }
      request_payload do
        File.read('spec/fixtures/files/request_payload_github_pull_request_closed.json')
      end
    end

    trait :push do
      hook_event { 'push' }
      hook_action { nil }
      generic_event_type { 'push' }
      event_source_name { '97561db8664eaf86a1e4c7b77d5fb5d5bff6681e' }
      request_headers do
        <<~END_OF_HEADERS
          HTTP_X_GITHUB_EVENT: push
        END_OF_HEADERS
      end
      request_payload do
        File.read('spec/fixtures/files/request_payload_github_push.json')
      end
    end

    trait :tag_push do
      hook_event { 'push' }
      hook_action { nil }
      generic_event_type { 'tag_push' }
      event_source_name { nil }
      request_headers do
        <<~END_OF_HEADERS
          HTTP_X_GITHUB_EVENT: push
        END_OF_HEADERS
      end
      request_payload do
        File.read('spec/fixtures/files/request_payload_github_tag_push.json')
      end
    end

    trait :succeeded do
      status { 'success' }
      response_body do
        <<~END_OF_RESPONSE_BODY
          <status code="ok">
            <summary>Ok</summary>
          </status>
        END_OF_RESPONSE_BODY
      end
      after(:create) do |workflow_run, _evaluator|
        SCMStatusReport.create(workflow_run: workflow_run,
                               response_body: "<status code=\"ok\">\n  <summary>Ok</summary>\n</status>\n",
                               request_parameters: JSON.generate({
                                                                   api_endpoint: workflow_run.response_url,
                                                                   target_repository_full_name: "#{workflow_run.repository_owner}/#{workflow_run.repository_name}",
                                                                   commit_sha: '6d86fdff6124833e688f93eb3b36c5393fb0e5e5',
                                                                   state: 'pending',
                                                                   status_options: {
                                                                     context: 'OBS:  - /',
                                                                     target_url: nil
                                                                   }
                                                                 }),
                               status: SCMStatusReport.statuses[:success])
      end
    end

    trait :failed do
      status { 'fail' }
      response_body do
        <<~END_OF_RESPONSE_BODY
          <status code="unknown">
            <summary>The 'target_project' key is missing</summary>
          </status>
        END_OF_RESPONSE_BODY
      end

      after(:create) do |workflow_run, _evaluator|
        SCMStatusReport.create(workflow_run: workflow_run,
                               response_body: "Failed to report back to #{workflow_run.scm_vendor}: Unauthorized request. Please check your credentials again.",
                               request_parameters: JSON.generate({
                                                                   api_endpoint: workflow_run.response_url,
                                                                   target_repository_full_name: "#{workflow_run.repository_owner}/#{workflow_run.repository_name}",
                                                                   commit_sha: '6d86fdff6124833e688f93eb3b36c5393fb0e5e5',
                                                                   state: 'pending',
                                                                   status_options: {
                                                                     context: 'OBS:  - /',
                                                                     target_url: nil
                                                                   }
                                                                 }),
                               status: SCMStatusReport.statuses[:fail])
      end
    end

    trait :pull_request_labeled do
      hook_event { 'pull_request' }
      hook_action { 'labeled' }
      generic_event_type { 'pull_request' }
      event_source_name { '1' }
      request_headers do
        <<~END_OF_HEADERS
          HTTP_X_GITHUB_EVENT: pull_request
          HTTP_X_GITHUB_HOOK_ID: 12345
          HTTP_X_GITHUB_DELIVERY: b4a6d950-110b-11ee-9095-943f7b2ddd1c
        END_OF_HEADERS
      end
      request_payload do
        File.read('spec/fixtures/files/request_payload_github_pull_request_labeled.json')
      end
    end
  end

  trait :pull_request_unlabeled do
    hook_event { 'pull_request' }
    hook_action { 'unlabeled' }
    generic_event_type { 'pull_request' }
    event_source_name { '1' }
    request_headers do
      <<~END_OF_HEADERS
        HTTP_X_GITHUB_EVENT: pull_request
        HTTP_X_GITHUB_HOOK_ID: 12345
        HTTP_X_GITHUB_DELIVERY: b4a6d950-110b-11ee-9095-943f7b2ddd1c
      END_OF_HEADERS
    end
    request_payload do
      File.read('spec/fixtures/files/request_payload_github_pull_request_unlabeled.json')
    end
  end

  # GitLab
  factory :workflow_run_gitlab, parent: :workflow_run do
    scm_vendor { 'gitlab' }
    hook_event { 'Merge Request Hook' }
    hook_action { 'open' }
    response_url { 'https://gitlab.com' }
    request_headers do
      <<~END_OF_HEADERS
        HTTP_X_GITLAB_EVENT: Merge Request Hook
      END_OF_HEADERS
    end
    request_payload do
      File.read('spec/fixtures/files/request_payload_gitlab_pull_request_opened.json')
    end

    trait :pull_request_closed do
      hook_action { 'close' }
      request_payload do
        File.read('spec/fixtures/files/request_payload_gitlab_pull_request_closed.json')
      end
    end

    trait :pull_request_merged do
      hook_action { 'merge' }
      request_payload do
        File.read('spec/fixtures/files/request_payload_gitlab_pull_request_merged.json')
      end
    end

    trait :push do
      hook_event { 'Push Hook' }
      hook_action { nil }
      generic_event_type { 'push' }
      event_source_name { '97561db8664eaf86a1e4c7b77d5fb5d5bff6681e' }
      request_headers do
        <<~END_OF_HEADERS
          HTTP_X_GITLAB_EVENT: Push Hook
        END_OF_HEADERS
      end
      request_payload do
        File.read('spec/fixtures/files/request_payload_gitlab_push.json')
      end
    end

    trait :tag_push do
      hook_event { 'Tag Push Hook' }
      hook_action { nil }
      generic_event_type { 'tag_push' }
      event_source_name { nil }
      request_headers do
        <<~END_OF_HEADERS
          HTTP_X_GITLAB_EVENT: Tag Push Hook
        END_OF_HEADERS
      end
      request_payload do
        File.read('spec/fixtures/files/request_payload_gitlab_tag_push.json')
      end
    end
  end
end
