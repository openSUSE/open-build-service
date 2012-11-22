class TC11__EditPackage < TestCase

  
  test :change_home_project_package_title do
  depend_on :create_home_project_package_for_user

    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1",
      :package => "HomePackage1"
    change_package_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s)
  end

  
  test :change_home_project_package_description do
  depend_on :create_home_project_package_for_user

    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1",
      :package => "HomePackage1"
    change_package_info(
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
  test :change_home_project_package_info do
  depend_on :create_home_project_package_for_user
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1",
      :package => "HomePackage1"
    change_package_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s,
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

    
  test :change_subproject_package_title do
  depend_on :create_subproject_package_for_user
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1:SubProject1",
      :package => "SubPackage1"
    change_package_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s)
  end

  
  test :change_subproject_package_description do
  depend_on :create_subproject_package_for_user
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1:SubProject1",
      :package => "SubPackage1"
    change_package_info(
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end
  
  test :change_subproject_package_info do
  depend_on :create_subproject_package_for_user
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1:SubProject1",
      :package => "SubPackage1"
    change_package_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s,
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
  test :change_global_project_package_title do
  depend_on :create_global_project_package
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:admin],
      :project => "PublicProject1",
      :package => "PublicPackage1"
    change_package_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s)
  end

  
  test :change_global_project_package_description do
  depend_on :create_global_project_package
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:admin],
      :project => "PublicProject1",
      :package => "PublicPackage1"
    change_package_info(
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
  test :change_global_project_package_info do
  depend_on :create_global_project_package
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:admin],
      :project => "PublicProject1",
      :package => "PublicPackage1"
    change_package_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s,
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
end
