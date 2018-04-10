# frozen_string_literal: true

RSpec.shared_context 'a github issue response' do
  let(:github_issues_json) do
    <<-JSON
    [
      {
        "url": "https://api.github.com/repos/openSUSE/open-build-service/issues/3628",
        "repository_url": "https://api.github.com/repos/openSUSE/open-build-service",
        "labels_url": "https://api.github.com/repos/openSUSE/open-build-service/issues/3628/labels{/name}",
        "comments_url": "https://api.github.com/repos/openSUSE/open-build-service/issues/3628/comments",
        "events_url": "https://api.github.com/repos/openSUSE/open-build-service/issues/3628/events",
        "html_url": "https://github.com/openSUSE/open-build-service/pull/3628",
        "id": 250934596,
        "number": 3628,
        "title": "[ci] Trying fix flickering test in test_helper",
        "user": {
          "login": "obsdev",
          "id": 1212806,
          "avatar_url": "https://avatars3.githubusercontent.com/u/1212806?v=4",
          "gravatar_id": "",
          "url": "https://api.github.com/users/obsdev",
          "html_url": "https://github.com/obsdev",
          "followers_url": "https://api.github.com/users/obsdev/followers",
          "following_url": "https://api.github.com/users/obsdev/following{/other_user}",
          "gists_url": "https://api.github.com/users/obsdev/gists{/gist_id}",
          "starred_url": "https://api.github.com/users/obsdev/starred{/owner}{/repo}",
          "subscriptions_url": "https://api.github.com/users/obsdev/subscriptions",
          "organizations_url": "https://api.github.com/users/obsdev/orgs",
          "repos_url": "https://api.github.com/users/obsdev/repos",
          "events_url": "https://api.github.com/users/obsdev/events{/privacy}",
          "received_events_url": "https://api.github.com/users/obsdev/received_events",
          "type": "User",
          "site_admin": false
        },
        "labels": [
          {
            "id": 21922370,
            "url": "https://api.github.com/repos/openSUSE/open-build-service/labels/frontend",
            "name": "frontend",
            "color": "c7def8",
            "default": false
          },
          {
            "id": 273955462,
            "url": "https://api.github.com/repos/openSUSE/open-build-service/labels/Test%20Suite",
            "name": "Test Suite",
            "color": "FEE0C6",
            "default": false
          }
        ],
        "state": "open",
        "locked": false,
        "assignee": null,
        "assignees": [

        ],
        "milestone": null,
        "comments": 0,
        "created_at": "2017-08-17T12:56:38Z",
        "updated_at": "2017-08-17T12:59:17Z",
        "closed_at": null,
        "pull_request": {
          "url": "https://api.github.com/repos/openSUSE/open-build-service/pulls/3628",
          "html_url": "https://github.com/openSUSE/open-build-service/pull/3628",
          "diff_url": "https://github.com/openSUSE/open-build-service/pull/3628.diff",
          "patch_url": "https://github.com/openSUSE/open-build-service/pull/3628.patch"
        },
        "body": "Trying to fix issue #3533"
      }
    ]
    JSON
  end
end
