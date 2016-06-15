FactoryGirl.define do
  factory :relationship do
    role { Role.find_by_title('maintainer') }

    factory :relationship_project_user do
      project
      user
    end

    factory :relationship_project_group do
      project
      group
    end

    factory :relationship_package_user do
      package
      user
    end

    factory :relationship_package_group do
      package
      group
    end
  end
end
