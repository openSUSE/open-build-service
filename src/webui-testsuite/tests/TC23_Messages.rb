class TC23__Groups < TestCase

  test :add_messages do
    depend_on :login_as_admin

    navigate_to MainPage, :user => $data[:admin]
    add_new_message "This is just a test", "Green"
    
  end

  test :delete_messages do
    depend_on :add_messages

    navigate_to MainPage, :user => $data[:admin]
    delete_message "This is just a test"
  end

end
