class TC02__Home < TestCase

  
  test :change_real_name_for_user do
  depend_on :login_as_user
    navigate_to MainPage, :user => $data[:user1]
    open_home
    change_user_real_name "New imaginary name " + Time.now.to_i.to_s
  end

  
  test :remove_user_real_name do
  depend_on :login_as_user
  
    navigate_to MainPage, :user => $data[:user1]
    open_home
    change_user_real_name ""
  end

  
  test :real_name_stays_changed do
  depend_on :login_as_user
  
    navigate_to MainPage, :user => $data[:user1]
    open_home
    new_name = "New imaginary name " + Time.now.to_i.to_s
    change_user_real_name new_name
    logout
    login_as $data[:user1]
    open_home
    assert new_name == user_real_name
  end

  
end
