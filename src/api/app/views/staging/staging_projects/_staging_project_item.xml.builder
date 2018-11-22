builder.staging_project(name: staging_project.name, state: staging_project.overall_state) do
  builder.staged_requests(count: staging_project.staged_requests.count) do
    render(partial: 'requests', locals: { requests: staging_project.staged_requests, builder: builder })
  end
  builder.untracked_requests(count: staging_project.untracked_requests.count) do
    render(partial: 'requests', locals: { requests: staging_project.untracked_requests, builder: builder })
  end
  builder.requests_to_review(count: staging_project.requests_to_review.count) do
    render(partial: 'requests', locals: { requests: staging_project.requests_to_review, builder: builder })
  end
  builder.obsolete_requests(count: staging_project.staged_requests.obsolete.count) do
    render(partial: 'requests', locals: { requests: staging_project.staged_requests.obsolete, builder: builder })
  end
  render(partial: 'missing_reviews', locals: { missing_reviews: staging_project.missing_reviews, count: staging_project.missing_reviews.count, builder: builder })
  render(partial: 'building_repositories', locals: { building_repositories: staging_project.building_repositories, count: staging_project.building_repositories.count, builder: builder })
  render(partial: 'broken_packages', locals: { broken_packages: staging_project.broken_packages, count: staging_project.broken_packages.count, builder: builder })
  render(partial: 'checks', locals: { checks: staging_project.checks, builder: builder })
  render(partial: 'missing_checks', locals: { missing_checks: staging_project.missing_checks, builder: builder })
end
