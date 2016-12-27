FactoryGirl.define do
  factory :attrib do
    attrib_type { create(:attrib_type_with_namespace) }

    factory :maintained_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'Maintained') }
    end

    factory :maintainance_project_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'MaintenanceProject') }
    end

    factory :template_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'ImageTemplates') }
    end

    factory :update_project_attrib do
      transient do
        update_project nil
      end

      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'UpdateProject') }
      values { [build(:attrib_value, value: update_project.name)] }
    end

    factory :project_status_package_fail_comment_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'ProjectStatusPackageFailComment') }
      values { [build(:attrib_value, value: Faker::Lorem.sentence)] }
    end
  end
end
