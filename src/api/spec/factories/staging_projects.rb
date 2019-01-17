FactoryBot.define do
  factory :staging_project, class: 'Staging::StagingProject', parent: :project do
    # Staging workflows have 2 staging projects by default, *:Staging:A and *:Staging:B.
    sequence(:name, [*'C'..'Z'].cycle) { |letter| "#{staging_workflow.project.name}:Staging:#{letter}" }
  end
end
