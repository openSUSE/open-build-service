require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class TagcloudTest < ActiveSupport::TestCase
  fixtures :all
  
  def test_max_min
    opt = Hash.new
    
    cloud = Tagcloud.new(opt)
    assert_kind_of Tagcloud, cloud
    
    assert_equal 4, cloud.max, "Wrong maximum."
    assert_equal 1, cloud.min, "Wrong minimum."
  end   
    
    
  def test_delta
    opt = Hash.new
    
    cloud = Tagcloud.new(opt)
    assert_kind_of Tagcloud, cloud
    
    steps = 6
    
    delta = cloud.delta(steps,cloud.max,cloud.min)
    #delta = (delta * 1000).round.to_f / 1000
    
    assert_equal 0.5, delta, "Wrong delta."
  end

  
  def test_sort_tags
    opt = Hash.new
    
    cloud = Tagcloud.new(opt)
    assert_kind_of Tagcloud, cloud
    
    #sort by name (default)
    cloud.sort_tags
    assert_kind_of Array, cloud.tags
    assert_not_nil cloud.tags
    
    predecessor = cloud.tags[0]
    cloud.tags.each do |tag|
      assert predecessor.name <= tag.name , "Error in sort_tags (by name), tags are not in alphabetical order"
      predecessor = tag
    end
    
    #sort by count
    opt = {:scope=>"count"}
    cloud.sort_tags(opt)
    assert_kind_of Array, cloud.tags
    assert_not_nil cloud.tags
    
    predecessor = cloud.tags[0]
    cloud.tags.each do |tag|
      assert predecessor.count >= tag.count , "Error in sort_tags (by count), tags are not in descending order"
      predecessor = tag
    end
  end
  
   
  def test_raw
    opt = Hash.new
    
    cloud = Tagcloud.new(opt)
    assert_kind_of Tagcloud, cloud
    
    rcloud = cloud.raw
    assert_kind_of Hash, rcloud

    assert_equal 3, rcloud['TagA'], "Wrong tag-count for TagA."
    assert_equal 4, rcloud['TagB'], "Wrong tag-count for TagB."
    assert_equal 4, rcloud['TagC'], "Wrong tag-count for TagC."
    assert_equal 1, rcloud['TagD'], "Wrong tag-count for TagD."
    assert_equal 1, rcloud['TagE'], "Wrong tag-count for TagE."
    assert_equal 1, rcloud['TagF'], "Wrong tag-count for TagF."
  end
  
  
  def test_logarithmic
    opt = Hash.new
    
    steps = 6
    
    cloud = Tagcloud.new(opt)
    assert_kind_of Tagcloud, cloud
    
    lcloud = cloud.logarithmic_distribution_method(steps)
    assert_kind_of Hash, lcloud
  
    assert_equal 5, lcloud['TagA'], "Wrong font size for TagA."
    assert_equal 6, lcloud['TagB'], "Wrong font size for TagB."
    assert_equal 6, lcloud['TagC'], "Wrong font size for TagC."
    assert_equal 0, lcloud['TagD'], "Wrong font size for TagD."
    assert_equal 0, lcloud['TagE'], "Wrong font size for TagE."
    assert_equal 0, lcloud['TagF'], "Wrong font size for TagF."      
  end
  
  
  def test_linear
    opt = Hash.new
    
    steps = 6
    
    cloud = Tagcloud.new(opt)
    assert_kind_of Tagcloud, cloud
    
    lcloud = cloud.linear_distribution_method(steps)
    assert_kind_of Hash, lcloud
    
    assert_equal 4, lcloud['TagA'], "Wrong font size for TagA."
    assert_equal 6, lcloud['TagB'], "Wrong font size for TagB."
    assert_equal 6, lcloud['TagC'], "Wrong font size for TagC."
    assert_equal 0, lcloud['TagD'], "Wrong font size for TagD."
    assert_equal 0, lcloud['TagE'], "Wrong font size for TagE."
    assert_equal 0, lcloud['TagF'], "Wrong font size for TagF."
  end
  
  
  def test_user_tagcloud
    
    #tag-cloud test for user 'Iggy'
    opt = Hash.new
    opt = {:scope => 'user', :user => User.find_by_login('Iggy')}
    
    cloud = Tagcloud.new(opt)
    assert_kind_of Tagcloud, cloud
    assert_not_nil cloud.tags
    
    #max_min check
    assert_equal 3, cloud.max
    assert_equal 1, cloud.min
    
    #total number of tags in this cloud
    assert_equal 6, cloud.tags.size, "Unexpected number of tags."
    
    cloud.tags.each do |tag|
      case tag.name
        when 'TagA'
          assert_equal 3, tag.count, "Wrong tag-count for #{tag.name}."
        when 'TagB'
          assert_equal 2, tag.count, "Wrong tag-count for #{tag.name}."
        when 'TagC'
          assert_equal 3, tag.count, "Wrong tag-count for #{tag.name}."
        when 'TagD'
          assert_equal 1, tag.count, "Wrong tag-count for #{tag.name}."
        when 'TagE'
          assert_equal 1, tag.count, "Wrong tag-count for #{tag.name}."
        when 'TagF'
          assert_equal 1, tag.count, "Wrong tag-count for #{tag.name}."
        else
          flunk "Unexpected tag in this tag-cloud."
      end
    end
    
    
    #same test for user 'fred'
    #tags = ['TagB','TagC']
    opt = {:scope => 'user', :user => User.find_by_login('fred')}
    
    cloud = Tagcloud.new(opt)
    assert_kind_of Tagcloud, cloud
    assert_not_nil cloud.tags
    
    #max_min check
    assert_equal 2, cloud.max
    assert_equal 1, cloud.min
    
    #total number of tags in this cloud
    assert_equal 2, cloud.tags.size, "Unexpected number of tags."

    cloud.tags.each do |tag|
      case tag.name
        when 'TagB'
          assert_equal 2, tag.count, "Wrong tag-count for #{tag.name}."
        when 'TagC'
          assert_equal 1, tag.count, "Wrong tag-count for #{tag.name}."
        else
          flunk "Unexpected tag in this tag-cloud."
      end
    end
  end
  
  
end
