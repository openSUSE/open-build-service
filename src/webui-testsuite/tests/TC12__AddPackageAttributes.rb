class TC12__AddPackageAttributes < TestCase


  test :add_all_permited_package_attributes_for_user do
  depend_on :create_home_project_package_for_user
  
    navigate_to PackageOverviewPage,
      :user => $data[:user1],
      :package => "HomePackage1",
      :project => "home:user1"
    open_tab "attributes"
    add_new_attribute(
      :name  => "OBS:RequestCloned",
      :value => "cloneclone")
    add_new_attribute(
      :name  => "OBS:ProjectStatusPackageFailComment",
      :value => "some_value_comment")
    add_new_attribute(
      :name  => "OBS:InitializeDevelPackage")
    # TODO: Add QualityCategory as it's obviously permited
    #       but still can't guess any acceptable values
  end


  test :add_all_permited_package_attributes_for_second_user do
  depend_on :create_home_project_package_for_second_user
  
    navigate_to PackageOverviewPage,
      :user => $data[:user2],
      :package => "Home2Package1",
      :project => "home:user2"
    open_tab "attributes"
    add_new_attribute(
      :name  => "OBS:RequestCloned",
      :value => "cloneclone")
    add_new_attribute(
      :name  => "OBS:ProjectStatusPackageFailComment",
      :value => "some_value_comment")
    add_new_attribute(
      :name  => "OBS:InitializeDevelPackage")
    # TODO: Add QualityCategory as it's obviously permited
    #       but still can't guess any acceptable values
  end


  test :add_all_not_permited_package_attributes_for_user do
  depend_on :create_home_project_package_for_user
  
    navigate_to PackageOverviewPage,
      :user => $data[:user1],
      :package => "HomePackage1",
      :project => "home:user1"
    open_tab "attributes"
    add_new_attribute(
      :name   => "OBS:VeryImportantProject",
      :value  => "",
      :expect => :no_permission)
    add_new_attribute(
      :name   => "OBS:UpdateProject",
      :value  => "",
      :expect => :no_permission)  
    add_new_attribute(
      :name   => "OBS:RejectRequests",
      :value  => "",
      :expect => :wrong_number_of_values)   
    add_new_attribute(
      :name   => "OBS:ApprovedRequestSource",
      :value  => "",
      :expect => :success)
    add_new_attribute(
      :name   => "OBS:Maintained",
      :value  => "",
      :expect => :success)   
    add_new_attribute(
      :name   => "OBS:MaintenanceProject",
      :value  => "",
      :expect => :no_permissions)
    add_new_attribute(
      :name   => "OBS:MaintenanceIdTemplate",
      :value  => "",
      :expect => :no_permission)   
    add_new_attribute(
      :name   => "OBS:ScreenShots",
      :value  => "",
      :expect => :no_permission)     
  end


  test :add_invalid_value_for_package_attribute do
  depend_on :create_home_project_for_user
  
    navigate_to PackageOverviewPage,
      :user => $data[:user1],
      :package => "HomePackage1",
      :project => "home:user1"
    open_tab "attributes"
    add_new_attribute(
      :name   => "OBS:QualityCategory",
      :value  => "invalid_value",
      :expect => :value_not_allowed)
  end


  test :wrong_number_of_values_for_package_attribute do
  depend_on :create_home_project_package_for_user
  
    navigate_to PackageOverviewPage,
      :user => $data[:user1],
      :package => "HomePackage1",
      :project => "home:user1"
    open_tab "attributes"
    add_new_attribute(
      :name   => "OBS:ProjectStatusPackageFailComment",
      :value  => "val1,val2,val3",
      :expect => :too_many_values)
  end


  test :add_same_package_attribute_twice do
  depend_on :create_home_project_package_for_user
  
    navigate_to PackageOverviewPage,
      :user => $data[:user1],
      :package => "HomePackage1",
      :project => "home:user1"
    open_tab "attributes"
    add_new_attribute(
      :name  => "OBS:RequestCloned",
      :value => "value1")
    add_new_attribute(
      :name  => "OBS:RequestCloned",
      :value => "value2")
  end


  test :add_all_admin_permited_package_attributes do
  depend_on :login_as_admin, :create_subproject_package_for_user
  
    navigate_to PackageOverviewPage,
      :user => $data[:admin],
      :package => "SubPackage1",
      :project => "home:user1:SubProject1"
    open_tab "attributes"
    add_new_attribute(
      :name  => "OBS:VeryImportantProject")
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


  test :add_all_admin_not_permited_package_attributes do
  depend_on :login_as_admin
  end


end
