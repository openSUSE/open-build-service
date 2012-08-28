class TC13__DeletePackageAttributes < TestCase


  test :delete_at_remote_package_package_as_user do
  depend_on :add_all_permited_package_attributes_for_second_user
  
    navigate_to PackageOverviewPage,
      :user    => $data[:user1],
      :package => "Home2Package1",
      :project => "home:user2"
    open_tab "attributes"
    delete_attribute(
      :name =>  "OBS:RequestCloned",
      :expect => :no_permission)
    delete_attribute(
      :name => "OBS:ProjectStatusPackageFailComment",
      :expect => :no_permission)
    delete_attribute(
      :name => "OBS:InitializeDevelPackage",
      :expect => :no_permission)
  end

  
  test :delete_all_user_permited_package_attributes do
  depend_on :add_all_permited_package_attributes_for_user
  
    navigate_to PackageOverviewPage,
      :user => $data[:user1],
      :package => "HomePackage1",
      :project => "home:user1"
    open_tab "attributes"
    delete_attribute :name => "OBS:RequestCloned"
    delete_attribute :name => "OBS:ProjectStatusPackageFailComment"
    delete_attribute :name => "OBS:InitializeDevelPackage"
  end


  test :delete_all_user_not_permited_package_attributes do
  depend_on :add_all_admin_permited_package_attributes
  
    navigate_to PackageOverviewPage,
      :user => $data[:user1],
      :package => "SubPackage1",
      :project => "home:user1:SubProject1"
    open_tab "attributes"
    delete_attribute(
      :name   => "OBS:VeryImportantProject",
      :expect => :no_permission)
    delete_attribute(
      :name   => "OBS:UpdateProject",
      :expect => :no_permission)
    delete_attribute :name   => "OBS:RejectRequests"
    delete_attribute :name   => "OBS:ApprovedRequestSource"
    delete_attribute :name   => "OBS:Maintained"
    delete_attribute :name   => "OBS:MaintenanceProject", :expect => :no_permission
    delete_attribute :name   => "OBS:MaintenanceIdTemplate", :expect => :no_permission
    delete_attribute :name   => "OBS:ScreenShots", :expect => :no_permission
    delete_attribute :name   => "OBS:RequestCloned"
    delete_attribute :name   => "OBS:ProjectStatusPackageFailComment"
    delete_attribute :name   => "OBS:InitializeDevelPackage"
  end


  test :delete_all_admin_permited_package_attributes do
  depend_on :add_all_admin_permited_package_attributes, :delete_all_user_not_permited_package_attributes
  
    navigate_to PackageOverviewPage,
      :user => $data[:admin],
      :package => "SubPackage1",
      :project => "home:user1:SubProject1"
    open_tab "attributes"
    delete_attribute :name => "OBS:VeryImportantProject"
    delete_attribute :name => "OBS:UpdateProject"
    delete_attribute :name => "OBS:MaintenanceProject"
    delete_attribute :name => "OBS:MaintenanceIdTemplate"
    delete_attribute :name => "OBS:ScreenShots"
  end


  test :delete_user_created_package_attributes_as_admin do
  depend_on :add_all_permited_package_attributes_for_second_user
  
    navigate_to PackageOverviewPage,
      :user => $data[:admin],
      :package => "Home2Package1",
      :project => "home:user2"
    open_tab "attributes"
    delete_attribute :name => "OBS:RequestCloned"
    delete_attribute :name => "OBS:ProjectStatusPackageFailComment"
    delete_attribute :name => "OBS:InitializeDevelPackage"
  end

  
end
