RSpec.shared_context 'a scm payload hash' do
  let(:github_extractor_payload) do
    {
      scm: 'github',
      repo_url: 'https://github.com/openSUSE/open-build-service',
      commit_sha: '387185b7df2b572377712994116c19cd7dd13150',
      pr_number: 123,
      source_branch: 'test_branch',
      target_branch: 'master',
      action: 'opened',
      repository_full_name: 'openSUSE/open-build-service',
      event: 'pull_request'
    }.with_indifferent_access
  end
  let(:gitlab_extractor_payload) do
    {
      scm: 'gitlab',
      object_kind: 'merge_request',
      http_url: 'http://example.com/gitlabhq/gitlab-test.git',
      commit_sha: 'da1560886d4f094c3e6c9ef40349f7d38b5d27d7',
      pr_number: 123,
      source_branch: 'test_branch',
      target_branch: 'master',
      action: 'open',
      project_id: 1,
      path_with_namespace: 'gitlabhq/gitlab-test',
      event: 'Merge Request Hook'
    }.with_indifferent_access
  end
end
