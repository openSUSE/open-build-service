class TC06__DeleteProjectAttributes < TestCase


  test :delete_project_attribute_at_remote_project_as_user do
  depend_on :add_all_permited_project_attributes_for_second_user
  
    navigate_to ProjectOverviewPage,
      :user    => $data[:user1],
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

  
  test :delete_all_user_permited_project_attributes do
  depend_on :add_all_permited_project_attributes_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "attributes"
    delete_attribute :name => "OBS:RequestCloned"
    delete_attribute :name => "OBS:ProjectStatusPackageFailComment"
    delete_attribute :name => "OBS:InitializeDevelPackage"
  end


  test :delete_all_user_not_permited_project_attributes do
  depend_on :add_all_admin_permited_project_attributes
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1:SubProject1"
    open_tab "attributes"
    delete_attribute(
      :name   => "OBS:VeryImportantProject",
      :expect => :no_permission)
    delete_attribute(
      :name   => "OBS:UpdateProject",
      :expect => :no_permission)
    delete_attribute( 
      :name   => "OBS:ScreenShots",
      :expect => :no_permission)
  end


  test :delete_all_admin_permited_project_attributes do
  depend_on :add_all_admin_permited_project_attributes
  
    navigate_to ProjectOverviewPage,
      :user => $data[:admin],
      :project => "home:user1:SubProject1"
    open_tab "attributes"
    delete_attribute :name => "OBS:VeryImportantProject"
    delete_attribute :name => "OBS:UpdateProject"
    delete_attribute :name => "OBS:RejectRequests"
    delete_attribute :name => "OBS:ApprovedRequestSource"
    delete_attribute :name => "OBS:Maintained"
    delete_attribute :name => "OBS:MaintenanceProject"
    delete_attribute :name => "OBS:MaintenanceIdTemplate"
    delete_attribute :name => "OBS:ScreenShots"
    delete_attribute :name => "OBS:RequestCloned"
    delete_attribute :name => "OBS:ProjectStatusPackageFailComment"
    delete_attribute :name => "OBS:InitializeDevelPackage"
  end


  test :delete_user_created_project_attributes_as_admin do
  depend_on :add_all_permited_project_attributes_for_second_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:admin],
      :project => "home:user2"
    open_tab "attributes"
    delete_attribute :name => "OBS:RequestCloned"
    delete_attribute :name => "OBS:ProjectStatusPackageFailComment"
    delete_attribute :name => "OBS:InitializeDevelPackage"
  end

  
end
