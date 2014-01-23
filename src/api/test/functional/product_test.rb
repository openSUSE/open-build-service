require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class ProductTests < ActionDispatch::IntegrationTest 
  fixtures :all
  
  def test_simple_product_file
    login_tom
    put "/source/home:tom:temporary/_meta",
        '<project name="home:tom:temporary"> <title/> <description/> 
           <repository name="me" />
         </project>'
    assert_response :success
    put "/source/home:tom:temporary/_product/_meta",
        '<package project="home:tom:temporary" name="_product"> <title/> <description/> 
            <person userid="adrian" role="maintainer" />
         </package>'
    assert_response :success

    # everything works even when the project is not owner by me?
    login_adrian
    # upload sources in right order
    ["defaults-archsets.include", "defaults-conditionals.include", "defaults-repositories.include", "obs.group", "obs-release.spec", "simple.product"].each do |file|
      raw_put "/source/home:tom:temporary/_product/#{file}",
              File.open("#{Rails.root}/test/fixtures/backend/source/simple_product/#{file}").read()
      assert_response :success
    end

    get "/source/home:tom:temporary/_product?view=issues"
    assert_response :success
    assert_xml_tag :tag => "kind", :content => "product"
    get "/source/home:tom:temporary/_product?view=products"
    assert_response :success
    assert_xml_tag :tag => "product", :attributes => { :id => 'simple' }
    assert_equal "simple", Package.find_by_project_and_name("home:tom:temporary","_product").products.first.name

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
    assert_match(/Illegal support key ILLEGAL for obs-server/, @response.body)

    login_tom
    delete "/source/home:tom:temporary"
    assert_response :success
  end

end
