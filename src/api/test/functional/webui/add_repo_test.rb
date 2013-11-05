require 'test_helper'

class Webui::AddRepoTest < Webui::IntegrationTest

  def setup
    super
    visit '/'
    login_Iggy
    
    find('.mainhead').must_have_text("Welcome to Open Build Service")
  end

   def test_add_default
     within('#subheader') do
       click_link 'Home Project'
     end

     click_link 'Repositories'
     page.must_have_text("Repositories of home:Iggy")
     page.must_have_text(/i586, x86_64/)

     click_link 'Add repositories'
     page.must_have_text("Add Repositories to Project home:Iggy")

     page.must_have_text("KIWI image build")

     find('#submitrepos')['disabled'].must_equal 'disabled'
     
     check 'repo_images'
     click_button "Add selected repositories"
   end
   
end

