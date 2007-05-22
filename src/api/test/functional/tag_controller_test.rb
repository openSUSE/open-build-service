require File.dirname(__FILE__) + '/../test_helper'
require 'tag_controller'

# Re-raise errors caught by the controller.
class TagController; def rescue_action(e) raise e end; end

class TagControllerTest < Test::Unit::TestCase

  fixtures :users, :db_projects, :db_packages, :tags, :taggings, :blacklist_tags
  
  def setup
    @controller = TagController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    #wrapper for testing private functions
    def @controller.private_s_to_tag(tag)
      s_to_tag(tag)
    end
    
    
    def @controller.private_taglistXML_to_tags(taglistXML)
      taglistXML_to_tags(taglistXML)
    end
    
  end
  
  
  def test_s_to_tag
    t = Tag.find_by_name("TagX")
    assert_nil t, "Precondition check failed, TagX already exists"
    
    #create a new tag
    t = @controller.private_s_to_tag("TagX")
    assert_kind_of Tag, t
    
    #find an existing tag
    t = @controller.private_s_to_tag("TagA")
    assert_kind_of Tag, t
    
    #expected exceptions 
    assert_raises (RuntimeError) {
      @controller.private_s_to_tag("IamNotAllowed")
      }
    
    assert_raises (RuntimeError) {
      @controller.private_s_to_tag("NotAllowedSymbol:?")
      }
    
  end
  
  
  def test_create_relationship
  end
  
  
  def test_save_tags
  end
  
  
  def test_taglistXML_to_tags
  end
  
  
  def test_project_tags
  end
  
  
  def test_package_tags
  end
  
  
  def test_taglistXML_to_tags
  end
  
  
  def test_taglistXML_to_tags
  end
  
  
  def test_get_tags_by_user_and_project
  end
  
  
  def test_get_tags_by_user_and_package
  end
  
  
  def test_get_tags_by_user
  end
  
  
  def test_get_tagged_projects_by_user
  end
  
  
  def test_get_tagged_packages_by_user
  end
  
  
  def test_get_projects_by_tag
  end
  
  
  def test_get_packages_by_tag
  end
  
  
  def test_get_objects_by_tag
  end

end
