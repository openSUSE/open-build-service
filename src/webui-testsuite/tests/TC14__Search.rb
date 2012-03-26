class TC14__Search < TestCase


  test :search_for_home_projects do
  depend_on :create_home_project_for_user,
            :create_home_project_for_second_user,
            :create_home_project_for_admin
  
    navigate_to SearchPage, :user => :none
    search(
      :text => "Home", 
      :for  => [:projects], 
      :in   => [:title])
    refresh_page
    results = search_results
    #puts results.inspect
    assert results.include? :type => :project, :project_name => "home:user1"
    assert results.include? :type => :project, :project_name => "home:user2" 
    assert results.include? :type => :project, :project_name => "home:king" 
    # the api fixtures add home dirs too
    assert results.count >= 3
  end


  test :search_for_subprojects do
  depend_on :create_subproject_for_user,
            :create_subproject_with_only_name,
            :create_subproject_with_long_description
  
    navigate_to SearchPage, :user => :none
    search(
      :text => "Sub", 
      :for  => [:projects], 
      :in   => [:name])
    refresh_page
    results = search_results
    assert results.include? :type => :project, :project_name => "home:user1:SubProject1"
    assert results.include? :type => :project, :project_name => "home:user1:SubProject2"
    assert results.include? :type => :project, :project_name => "home:user1:SubProject3"
    assert results.count == 3
  end


  test :search_for_public_projects do
  depend_on :create_global_project
    
    navigate_to SearchPage, :user => :none
    search(
      :text => "Public", 
      :for  => [:projects], 
      :in   => [:name])
    refresh_page
    assert search_results.include? :type => :project, :project_name => "PublicProject1"
    assert search_results.count == 1
  end


  test :search_for_packages do
  depend_on :create_home_project_package_for_user
    
    navigate_to SearchPage, :user => :none
    search(
      :text => "Public", 
      :for  => [:projects], 
      :in   => [:name])
    refresh_page
    assert search_results.include? :type => :project, :project_name => "PublicProject1"
    assert search_results.count == 1
  end
  

  test :search_by_title do
    skip
  end


  test :search_by_description do
    skip
  end


  test :search_by_attributes do
    skip
  end


  test :search_non_existing_by_name do
  
    navigate_to SearchPage, :user => :none
    search(
      :text => "no such name, please!", 
      :for  => [:projects, :packages], 
      :in   => [:name])
    refresh_page
    assert search_results.empty?
  end


  test :search_non_existing_by_title do
  
    navigate_to SearchPage, :user => :none
    search(
      :text => "Perhaps a non-existing title.", 
      :for  => [:projects, :packages], 
      :in   => [:title])
    refresh_page
    assert search_results.empty?
  end


  test :search_non_existing_by_description do
  
    navigate_to SearchPage, :user => :none
    search(
      :text => "Some non-existing description I hope.", 
      :for  => [:projects, :packages], 
      :in   => [:description])
    refresh_page
    assert search_results.empty?
  end


  test :search_non_existing_by_attributes do
  
    navigate_to SearchPage, :user => :none
    search(
      :text => "", 
      :for  => [:projects, :packages], 
      :in   => [],
      :attribute => "OBS:RequestCloned")
    refresh_page
    assert search_results.empty?
  end


  test :search_for_nothing do
  
    navigate_to SearchPage, :user => :none
    search(
      :text => "Some empty search.", 
      :for  => [], 
      :in   => [:name, :title, :description])
    refresh_page
    assert search_results.empty?
  end
  
  
  test :search_in_nothing do
  
    navigate_to SearchPage, :user => :none
    search(
      :text => "Some empty search again.", 
      :for  => [:projects, :packages], 
      :in   => [],
      :expect => :invalid_search_options)
  end
  
  
  test :search_with_empty_text do
  
    navigate_to SearchPage, :user => :none
    search(
      :text => "", 
      :for  => [:projects, :packages], 
      :in   => [:name],
      :expect => :invalid_search_text)
  end
  
  
end
