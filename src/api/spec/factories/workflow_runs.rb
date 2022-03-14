FactoryBot.define do
  factory :workflow_run do
    token { create(:workflow_token) }
    request_headers do
      <<~END_OF_HEADERS
        HTTP_X_GITHUB_EVENT: pull_request
      END_OF_HEADERS
    end
    request_payload do
      <<~END_OF_PAYLOAD
        {
          "action": "opened",
          "pull_request": {
            "number": 1
          },
          "repository": {
            "full_name": "iggy/hello_world",
            "owner": { "html_url": "https://github.com" }
          },
          "foo": "bar"
        }
      END_OF_PAYLOAD
    end

    factory :succeeded_workflow_run do
      status { 'success' }
      response_body do
        <<~END_OF_RESPONSE_BODY
          <status code="ok">
            <summary>Ok</summary>
          </status>
        END_OF_RESPONSE_BODY
      end
      response_url { 'https://api.github.com' }
    end

    factory :running_workflow_run do
      status { 'running' }
      response_body { nil }
      response_url { nil }
    end

    factory :failed_workflow_run do
      status { 'fail' }
      response_body do
        <<~END_OF_RESPONSE_BODY
          <status code="unknown">
            <summary>The 'target_project' key is missing</summary>
          </status>
        END_OF_RESPONSE_BODY
      end
    end
  end
end
