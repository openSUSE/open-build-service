
class Tagcloud
  
  # :scope => :global | :user, :user => user 
  def initialize(opt)
    if opt[:scope] == "user"
      #puts "[TAG:] user-dependent tag cloud selected"
      user = opt[:user]
      @tags = user.tags.find(:all, :group => "name")
      #initialize the tag count in the user context
      @tags.each do |tag|
        tag.count(:scope => "user", :user => user)
      end
    else          
      @tags = Tag.find(:all, :group => "name")
      #initialize the tag count and remove unused tags from the list 
      @tags.delete_if {|tag| tag.count(:scope => "global") == 0 }   
    end
    @max, @min = max_min(@tags)
  end
  
  
  #    def get_weight(tag)
  #        if tag.class == "String"
  #            tag = Tag.find_by_name(tag)
  #        end
  #        @tagcloud[tag]
  #    end
  
  
  def top50
    #...how many should it be?
  end 
  
  
  def max_min(taglist)


    max, min = taglist[0].count, taglist[0].count  
    taglist.each do |tag|

      max = tag.count if tag.count > max
      min = tag.count if tag.count < min
    end
    return max, min
  end    
  
  
  def delta(steps,max,min)
    delta = 0
    if max != min
      delta = (max - min) / steps.to_f
    else
      delta = (max) / steps.to_f
    end
    return delta
  end
  
  
  def get_tags(distribution_method,steps)
    delta = delta(steps,@max,@min)
    tagcloud = {}
    
    case distribution_method
    when "linear"
      thresholds = thresholds_linear_distribution(steps,@max,@min,delta)
      @tags.each do |tag|
        tagcloud[tag.name] = linear_distribution_method(steps,thresholds,tag)
      end
    when "logarithmic"
      thresholds = thresholds_linear_distribution(steps,@max,@min,delta)
      @tags.each do |tag.name|
        tagcloud[tag] = logarithmic_distribution_method(steps,thresholds,tag)
      end
    when "raw"
      @tags.each do |tag|
        tagcloud[tag.name] = tag.count
      end
    else 
      raise ArgumentError.new "unknown distribution method '#{distribution_method}'"
    end
    
    taglist = tagcloud.sort {|a,b| a[0] <=> b[0]}
    
    return taglist
  end
  
  
  def linear_distribution_method(steps,thresholds,tag)
    size = 0
    for i in 1..steps
      if tag.count <= thresholds[i-1]
        size = i
        break
      end
    end
    return size
  end
  
  
  def logarithmic_distribution_method(steps,thresholds,tag)
    size = 0
    for i in 1..steps
      if 100 * Math.log(tag.weight + 2) <= thresholds[i-1]
        size = i
        break
      end
    end
    return size
  end
  
  
  def thresholds_linear_distribution(steps,max,min,delta)
    thresholds = []
    for i in 1..steps
      size = i
      thresholds << min + size * delta
    end
    return thresholds  
  end
  
  
  def thresholds_logarithmic_distribution(steps,max,min,delta)
    thresholds = []
    for i in 1..steps
      size = i
      thresholds << 100 * Math.log(min + size * delta + 2)
    end
    return thresholds
  end
  
end
