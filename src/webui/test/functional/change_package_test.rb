require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ChangePackageTest < ActionDispatch::IntegrationTest

   def setup
     super
     login_Iggy
   end

   def test_search_package
     fill_in 'search', with: 'kdelibs'
     find('#search').native.send_keys :enter
     assert page.has_text?("project home:coolo:test")
     
     click_link 'kdelibs_DEVEL_package'
   end
   
end

