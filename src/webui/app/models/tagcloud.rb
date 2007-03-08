class Tagcloud
  
  attr_reader :tags
  
  def initialize(opts = {:tagcloud => "mytags"})
    
    if  opts[:tagcloud] == "alltags"  or opts[:tagcloud] == "hierarchical_browsing"
      @tagcloudXML = Tag.find(:tagcloud)
    else
      @tagcloudXML = tagcloud_by_user(:user => opts[:user])
    end
    @tags = []
    @tagcloudXML.each_tag do |tag|
      @tags << tag
    end
  end
  
  
  def tagcloud_by_user(opts)
    tagcloudXML = Tag.find(:tagcloud_by_user, :user => opts[:user])
  end
  
  
end
