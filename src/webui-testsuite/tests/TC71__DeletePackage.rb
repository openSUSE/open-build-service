class TC71__DeletePackage < TestCase


  test :delete_subproject_package_for_user do
  depend_on :create_subproject_package_for_user

    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1:SubProject1",
      :package => "SubPackage1"
    delete_package
  end

  
  test :delete_home_project_package_for_user do
  depend_on :create_home_project_package_for_user
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1",
      :package => "HomePackage1"
    delete_package
  end


  test :delete_global_project_package do
  depend_on :create_global_project_package

    navigate_to PackageOverviewPage, 
      :user    => $data[:admin],
      :project => "PublicProject1",
      :package => "PublicPackage1"
    delete_package
  end


end
