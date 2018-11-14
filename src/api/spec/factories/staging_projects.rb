FactoryBot.define do
  factory :staging_project, class: 'Staging::StagingProject', parent: :project do
    sequence(:name, [*'A'..'Z'].cycle) { |letter| "#{staging_workflow.project.name}:Staging:#{letter}" }
  end
end
