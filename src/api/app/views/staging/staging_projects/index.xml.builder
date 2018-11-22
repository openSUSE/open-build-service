xml.staging_projects do
  @staging_projects.each do |staging_project|
    xml.staging_project(name: staging_project.name) do
      render(partial: 'staging/staging_projects/staged_requests', locals: { staged_requests: staging_project.staged_requests,
                                                                            count: staging_project.staged_requests.count, builder: xml })

      render(partial: 'staging/staging_projects/untracked_requests', locals: { untracked_requests: staging_project.untracked_requests,
                                                                               count: staging_project.untracked_requests.count, builder: xml  })

      render(partial: 'staging/staging_projects/requests_to_review', locals: { requests_to_review: staging_project.requests_to_review,
                                                                               count: staging_project.requests_to_review.count, builder: xml  })

      render(partial: 'staging/staging_projects/missing_reviews', locals: { missing_reviews: staging_project.missing_reviews,
                                                                            count: staging_project.missing_reviews.count, builder: xml })

      render(partial: 'staging/staging_projects/building_repositories', locals: { building_repositories: staging_project.building_repositories,
                                                                                  count: staging_project.building_repositories.count, builder: xml })

      render(partial: 'staging/staging_projects/broken_packages', locals: { broken_packages: staging_project.broken_packages,
                                                                            count: staging_project.broken_packages.count, builder: xml })
    end
  end
end
