FactoryBot.define do
  factory :attrib do
    attrib_type
    project

    transient do
      package { nil }
    end

    before(:create) do |attrib, evaluator|
      if evaluator.package
        attrib.package = evaluator.package
        attrib.project = nil
      end
    end

    factory :very_important_project_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'VeryImportantProject') }
    end

    factory :maintained_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'Maintained') }
    end

    factory :maintenance_project_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'MaintenanceProject') }
    end

    factory :template_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'ImageTemplates') }
    end

    factory :delegate_requests_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'DelegateRequestTarget') }
    end

    factory :approved_request_source_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'ApprovedRequestSource') }
    end

    factory :owner_root_project_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'OwnerRootProject') }
    end

    factory :enforce_revisions_in_requests_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'EnforceRevisionsInRequests') }
    end

    factory :update_project_attrib do
      transient do
        update_project { nil }
      end

      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'UpdateProject') }
      values { [build(:attrib_value, value: update_project.name)] }
    end

    factory :project_status_package_fail_comment_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'ProjectStatusPackageFailComment') }
      values { [build(:attrib_value, value: Faker::Lorem.sentence)] }
    end

    factory :auto_cleanup_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'AutoCleanup') }

      values { [build(:attrib_value, value: (Time.now - 14.days).to_s)] }
    end

    factory :embargo_date_attrib do
      attrib_type { AttribType.find_by_namespace_and_name!('OBS', 'EmbargoDate') }
      values { [build(:attrib_value, value: (Time.now.utc + 2.days).to_s)] }
    end

    factory :attrib_with_default_value do
      attrib_type { association :attrib_type_with_default_value }
    end
  end
end
