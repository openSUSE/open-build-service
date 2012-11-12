require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class AddRepoTest < ActionDispatch::IntegrationTest

  def setup
    super
    visit '/'
    login_Iggy
    
    assert find('.mainhead').has_text?("Welcome to Open Build Service")
  end

   def test_add_default
     within('#subheader') do
       click_link 'Home Project'
     end

     click_link 'Repositories'
     assert page.has_text?("Repositories of home:Iggy")
     assert page.has_text?(/i586, x86_64/)

     click_link 'Add repositories'
     page.has_text?("Add Repositories to Project home:Iggy")

     assert page.has_text?("KIWI image build")

     assert_equal 'true', find('#submitrepos')['disabled']
     
     check 'repo_images'
     click_button "Add selected repositories"
   end
   
end

