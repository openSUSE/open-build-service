require File.dirname(__FILE__) + '/../test_helper'

class TagTest < Test::Unit::TestCase
  fixtures :tags, :blacklist_tags, :taggings, :users

  def test_reject_tag
    t = Tag.new
    t.name = 'IamNotAllowed'
    t.created_at = "2007-03-09 14:57:54"
    assert t.save == false
    
    #expected error message
    assert_equal "The tag is blacklisted!", t.errors[:name]
    
    t = Tag.new
    t.name = 'NotAllowedSymbol_?'
    t.created_at = "2007-03-09 14:57:54"
    assert t.save == false
    
    #expected error message
    assert_equal "The tag has invalid format, no ? allowed!", t.errors[:name]
    
    t = Tag.new
    t.name = 'NotAllowedSymbol_:'
    t.created_at = "2007-03-09 14:57:54"
    assert t.save == false
    
    #expected error message
    assert_equal "The tag has invalid format, no : allowed!", t.errors[:name]
    
    
  end

  
  def test_count
    
    #non-user context
    t = Tag.find_by_name("TagA")
    assert_kind_of Tag, t
    assert_equal 3, t.count, "Wrong tag-count for TagA."
    
    t = Tag.find_by_name("TagB")
    assert_kind_of Tag, t
    assert_equal 4, t.count, "Wrong tag-count for TagB."
    
    #user-context
    u = User.find_by_login('tscholz')
    assert_kind_of User, u
    
    opt = {:scope => 'user', :user => u}
    
    t = Tag.find_by_name("TagA")
    assert_kind_of Tag, t
    assert_equal 3, t.count(opt), "Wrong user-dependant tag-count for TagA."
    
    t = Tag.find_by_name("TagB")
    assert_kind_of Tag, t
    assert_equal 2, t.count(opt), "Wrong user-dependant tag-count for TagB."
       
  end


end
