class Tagcloud
    
    attr_reader :tags

    def initialize(opts = {:tagcloud => "mytags"})
      
      if  opts[:tagcloud] == "alltags"
        @tagcloudXML = Tag.find(:tagcloud)
      else
        @tagcloudXML = Tag.find(:tags_by_user, :user => opts[:user])
      end
      @tags = []
      @tagcloudXML.each_tag do |tag|
        @tags << tag
      end
    end

end
