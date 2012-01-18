class TC11__EditPackage < TestCase

  
  test :switch_home_project_package_tabs do
  depend_on :create_home_project_package_for_user

    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1",
      :package => "HomePackage1"
    switch_tabs
  end

  
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

    
  test :switch_subproject_package_tabs do
  depend_on :create_subproject_package_for_user
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1:SubProject1",
      :package => "SubPackage1"
    switch_tabs
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

  
  test :switch_global_project_package_tabs do
  depend_on :create_global_project_package
  
    navigate_to PackageOverviewPage, 
      :user    => $data[:admin],
      :project => "PublicProject1",
      :package => "PublicPackage1"
    switch_tabs
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

  
  def switch_tabs
    open_tab "Attributes" 
    open_tab "Meta"
    open_tab "Sources"
    open_tab "Overview"
    open_tab "Revisions"
    open_tab "Repositories" 
    open_tab "Requests"
    open_tab "Users"
  end
  
  
end
