require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ChangePackageTest < ActionDispatch::IntegrationTest

   def setup
     super
     login_Iggy
   end

   def test_search_package
     fill_in 'search', with: 'kdelibs'
     page.evaluate_script("$('#global-search-form').get(0).submit()")
     page.must_have_text("project home:coolo:test")
     
     click_link 'kdelibs_DEVEL_package'
   end
   
end

