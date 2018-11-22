builder.staging_project(name: staging_project.name) do
  render(partial: 'staged_requests', locals: { staged_requests: staging_project.staged_requests, count: staging_project.staged_requests.count, builder: builder })

  render(partial: 'untracked_requests', locals: { untracked_requests: staging_project.untracked_requests, count: staging_project.untracked_requests.count, builder: builder  })

  render(partial: 'requests_to_review', locals: { requests_to_review: staging_project.requests_to_review, count: staging_project.requests_to_review.count, builder: builder  })

  render(partial: 'missing_reviews', locals: { missing_reviews: staging_project.missing_reviews, count: staging_project.missing_reviews.count, builder: builder })

  render(partial: 'building_repositories', locals: { building_repositories: staging_project.building_repositories, count: staging_project.building_repositories.count, builder: builder })

  render(partial: 'broken_packages', locals: { broken_packages: staging_project.broken_packages, count: staging_project.broken_packages.count, builder: builder })

  builder.overall_state(result: staging_project.overall_state)
  render(partial: 'checks', locals: { checks: staging_project.checks, builder: builder })
  render(partial: 'missing_checks', locals: { missing_checks: staging_project.missing_checks, builder: builder })
end
