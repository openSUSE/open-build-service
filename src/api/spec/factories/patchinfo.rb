FactoryBot.define do
  factory :patchinfo_base, class: 'Patchinfo' do
    initialize_with { new(**attributes) }

    # Patchinfo is an ActiveModel::Model. Override FactoryBot `create` method
    skip_create

    factory :patchinfo do
      initialize_with do
        new(**attributes.slice(:data))
          .create_patchinfo(attributes[:project_name], attributes[:package_name], **attributes.except(:data, :project_name, :package_name))
      end
    end
  end
end
