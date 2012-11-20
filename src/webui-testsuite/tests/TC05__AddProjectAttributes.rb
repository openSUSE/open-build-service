class TC05__AddProjectAttributes < TestCase


  test :add_all_permited_project_attributes_for_user do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectAttributesPage,
      :user => $data[:user1],
      :project => "home:user1"
    add_new_attribute(
      :name  => "OBS:RequestCloned",
      :value => "cloneclone")
    add_new_attribute(
      :name  => "OBS:ProjectStatusPackageFailComment",
      :value => "some_value_comment")
    add_new_attribute(
      :name  => "OBS:InitializeDevelPackage")
    add_new_attribute(
      :name  => "OBS:QualityCategory",
      :value => "Stable")
  end


  test :add_all_permited_project_attributes_for_second_user do
  depend_on :create_home_project_for_second_user
  
    navigate_to ProjectAttributesPage,
      :user => $data[:user2],
      :project => "home:user2"
    add_new_attribute(
      :name  => "OBS:RequestCloned",
      :value => "cloneclone")
    add_new_attribute(
      :name  => "OBS:ProjectStatusPackageFailComment",
      :value => "some_value_comment")
    add_new_attribute(
      :name  => "OBS:InitializeDevelPackage")
    add_new_attribute(
      :name  => "OBS:QualityCategory",
      :value => "Stable")
  end


  test :add_all_not_permited_project_attributes_for_user do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectAttributesPage,
      :user => $data[:user1],
      :project => "home:user1"
    add_new_attribute(
      :name   => "OBS:VeryImportantProject",
      :value  => "",
      :expect => :no_permission)
  end


  test :add_invalid_value_for_project_attribute do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectAttributesPage,
      :user => $data[:user1],
      :project => "home:user1"
    add_new_attribute(
      :name   => "OBS:QualityCategory",
      :value  => "invalid_value",
      :expect => :value_not_allowed)
  end


  test :wrong_number_of_values_for_project_attribute do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectAttributesPage,
      :user => $data[:user1],
      :project => "home:user1"
    add_new_attribute(
      :name   => "OBS:ProjectStatusPackageFailComment",
      :value  => "val1,val2,val3",
      :expect => :wrong_number_of_values)
  end


  test :add_same_project_attribute_twice do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectAttributesPage,
      :user => $data[:user1],
      :project => "home:user1"
    add_new_attribute(
      :name  => "OBS:RequestCloned",
      :value => "value1")
    add_new_attribute(
      :name  => "OBS:RequestCloned",
      :value => "value2")
  end


  test :add_all_admin_permited_project_attributes do
  depend_on :login_as_admin, :create_subproject_for_user
  
    navigate_to ProjectAttributesPage,
      :user => $data[:admin],
      :project => "home:user1:SubProject1"
    add_new_attribute(
      :name  => "OBS:VeryImportantProject")
    add_new_attribute(
      :name  => "OBS:OwnerRootProject",
      :value => "BugownerOnly")
    add_new_attribute(
      :name  => "OBS:UpdateProject",
      :value => "now")
    add_new_attribute(
      :name  => "OBS:RejectRequests",
      :value => "yes")   
    add_new_attribute(
      :name  => "OBS:ApprovedRequestSource")   
    add_new_attribute(
      :name  => "OBS:Maintained")   
    add_new_attribute(
      :name  => "OBS:MaintenanceProject",
      :value => "")   
    add_new_attribute(
      :name  => "OBS:MaintenanceIdTemplate",
      :value => "dontbesilly")   
    add_new_attribute(
      :name  => "OBS:ScreenShots",
      :value => "scarystuff")
    add_new_attribute(
      :name  => "OBS:RequestCloned",
      :value => "cloneclone")
    add_new_attribute(
      :name  => "OBS:ProjectStatusPackageFailComment",
      :value => "some_value_comment")
    add_new_attribute(
      :name  => "OBS:InitializeDevelPackage")
  end


  test :add_all_admin_not_permited_project_attributes do
  depend_on :login_as_admin
  end


end
