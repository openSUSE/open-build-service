FactoryGirl.define do
  factory :relationship_project_user, class: Relationship do
    project
    user
    role { Role.find_by_title('maintainer') }
  end

  factory :relationship_project_group, class: Relationship do
    project
    group
    role { Role.find_by_title('maintainer') }
  end

  factory :relationship_package_user, class: Relationship do
    package
    user
    role { Role.find_by_title('maintainer') }
  end

  factory :relationship_package_group, class: Relationship do
    package
    group
    role { Role.find_by_title('maintainer') }
  end
end
