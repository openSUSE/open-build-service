require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class ProductTests < ActionController::IntegrationTest 
  fixtures :all
  
  def test_simple_product_file
    prepare_request_with_user "tom", "thunder"
    put "/source/home:tom:temporary/_meta",
        '<project name="home:tom:temporary"> <title/> <description/> 
           <repository name="me" />
         </project>'
    assert_response :success
    put "/source/home:tom:temporary/_product/_meta",
        '<package project="home:tom:temporary" name="_product"> <title/> <description/> 
         </package>'
    assert_response :success

    # upload sources in right order
    for file in ["defaults-archsets.include", "defaults-conditionals.include", "defaults-repositories.include", "obs.group", "obs-release.spec", "simple.product"]
      raw_put "/source/home:tom:temporary/_product/#{file}",
        File.open("#{Rails.root}/test/fixtures/backend/source/simple_product/#{file}").read()
      assert_response :success
    end

    get "/source/home:tom:temporary"
    assert_response :success

    get "/source/home:tom:temporary/_product:simple-SP3-migration/simple-SP3-migration.spec"
    assert_response :success
    get "/source/home:tom:temporary/_product:simple-release/simple-release.spec"
    assert_response :success
    get "/source/home:tom:temporary/_product:sle-obs-cd-cd-i586_x86_64/sle-obs-cd-cd-i586_x86_64.kiwi"
    assert_response :success
    assert_xml_tag :tag => "source", :attributes => { :path => "obs://home:Iggy/10.2" },
                   :parent => { :tag => "instrepo", :attributes => { :name => "repository_1", :priority => "1", :local => "true" } }
    assert_xml_tag :tag => "repopackage", :attributes => { :name => "skelcd-obs", :medium => "0", :removearch => "src,nosrc", :onlyarch => "i586,x86_64" },
                   :parent => { :tag => "metadata" }
    assert_xml_tag :tag => "repopackage", :attributes => { :name => "patterns-obs", :medium => "0", :removearch => "src,nosrc", :onlyarch => "i586,x86_64" },
                   :parent => { :tag => "metadata" }

    delete "/source/home:tom:temporary"
    assert_response :success
  end

#  def test_simple_kiwi_product_file
#    prepare_request_with_user "king", "sunflower"
#
#    put '/source/kde4/product/product.kiwi', File.open("#{Rails.root}/test/fixtures/backend/source/kde4/product/product.kiwi").read()
#    assert_response :success
#
#    run_scheduler("x86_64")
#    run_scheduler("i586")
#
#    # check build state
#    get "/build/kde4/_result"
#    assert_response :success
#print @response.body
#  end

end
