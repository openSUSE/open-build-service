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
    get "/source/home:tom:temporary/_product:sle-obs-cd-cd-i586_x86_64/sle-obs-cd-cd-i586_x86_64.kwd"
    assert_response :success
    assert_match(/^obs-server: \+Kwd:\\nsupport_l3\\n-Kwd:/, @response.body)

    # invalid uploads 
    raw_put "/source/home:tom:temporary/_product/obs.group",
      File.open("#{Rails.root}/test/fixtures/backend/source/simple_product/INVALID_obs.group").read()
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => '400', :origin => 'backend' }
    assert_xml_tag :tag => "summary", :content => "Illegal support key ILLEGAL for obs-server"

    delete "/source/home:tom:temporary"
    assert_response :success
  end

end
