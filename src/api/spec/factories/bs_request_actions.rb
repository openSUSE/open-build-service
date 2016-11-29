FactoryGirl.define do
  factory :bs_request_action do
    factory :bs_request_action_add_maintainer_role do
      type 'add_role'
      role { Role.find_by_title('maintainer') }
      person_name { create(:user).login }
    end
    factory :bs_request_action_add_bugowner_role do
      type 'add_role'
      role { Role.find_by_title('bugowner') }
      person_name { create(:user).login }
    end
    factory :bs_request_action_submit, class: BsRequestActionSubmit do
      type 'submit'
    end
  end
end
