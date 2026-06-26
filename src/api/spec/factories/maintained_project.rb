# Create a relationship between an update project and a maintenance project. Example:
#   project: openSUSE:Leap:15.4:Update
#   maintenance_project: openSUSE:Maintenance

FactoryBot.define do
  factory :maintained_project do
    project
    maintenance_project
  end
end
