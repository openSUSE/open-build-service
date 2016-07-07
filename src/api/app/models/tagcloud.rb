
class Tagcloud
  attr_reader :tags
  attr_reader :max
  attr_reader :min
  attr_reader :limit

  # :scope => "global" | "user" | by_given_objects, :user => user
  def initialize(opt)
    ApplicationRecord.logger.debug "[TAG:] building a new tag cloud."

    @limit = opt[:limit] or @limit = 0

    if opt[:scope] == "by_given_objects"
      ApplicationRecord.logger.debug "[TAG:] Building tag-cloud by given objects."
      objects = opt[:objects]
      @tags = []
      # get tags for each object and put them in a list.
      objects.each do |object|
        @tags = @tags + object.tags
      end
      @tags.each do |tag|
        tag.count(:scope => 'by_given_tags', :tags => @tags)
      end
      @tags.uniq!

    elsif opt[:scope] == "user"
      user = opt[:user]
      @tags = user.tags.group(:name)
      # initialize the tag count in the user context
      @tags.each do |tag|
        tag.count(:scope => "user", :user => user)
      end

    else
      @tags = Tag.includes(:taggings).to_a
      @tags.each do |tag|
        tag.cached_count = tag.taggings.count
      end

      # initialize the tag count and remove unused tags from the list
      @tags.delete_if {|tag| tag.count(:scope => "global") == 0 }
    end
    limit_tags
    @max, @min = max_min(@tags)
  end

  def limit_tags
    if @limit == 0
      return
    elsif @tags.size > @limit
      sort_tags(:scope => "count")
      @tags = @tags[0..@limit-1]
    end
  end

  def sort_tags( opt = {} )
    if opt[:scope] == "count"
      # descending order by count
      sorted = @tags.sort { |a, b| b.count<=>a.count }
      @tags = sorted
    else
      # alphabetical order (ascending order)
      sorted = @tags.sort { |a, b| a.name<=>b.name }
      @tags = sorted
    end
  end

  def top50
    # ...dummy
  end

  def max_min(taglist)
    if taglist.empty?
    max, min = 1, 1
    else
    max, min = taglist[0].count, taglist[0].count
    end

    taglist.each do |tag|
      max = tag.count if tag.count > max
      min = tag.count if tag.count < min
    end
    return max, min
  end

  def delta(steps, max, min)
    delta = 0
    if max != min
      delta = (max - min) / steps.to_f
    else
      delta = (max) / steps.to_f
    end
    return delta
  end

  def get_tags(distribution_method, steps)
    delta = delta(steps, @max, @min)
    tagcloud = {}

    case distribution_method
    when "linear"
      tagcloud = linear_distribution_method(steps)
    when "logarithmic"
     tagcloud = logarithmic_distribution_method(steps)

    when "raw"
     tagcloud = raw
    else
      raise ArgumentError.new("unknown distribution method '#{distribution_method}'")
    end

    taglist = tagcloud.sort {|a, b| a[0].downcase <=> b[0].downcase}

    return taglist
  end

  def raw
    tagcloud = Hash.new

    @tags.each do |tag|
        tagcloud[tag.name] = tag.count
    end

    return tagcloud
  end

  # new logarithmic distribution method
  def logarithmic_distribution_method(steps)
    minlog = Math.log(@min)
    maxlog = Math.log(@max)
    logrange = maxlog - minlog
    logrange = 1 if maxlog == minlog
    tagcloud = Hash.new
    @tags.each do |tag|
      ratio = (Math.log(tag.count) - minlog) / logrange
      fsize = (0 + steps) * ratio
      tagcloud[tag.name] = fsize.round
    end
    return tagcloud
  end

  # new linear distribution method
  def linear_distribution_method(steps)
    range = @max.to_f - @min.to_f
    range = 1 if @max == @min
    tagcloud = Hash.new
    @tags.each do |tag|
      ratio = (tag.count - @min.to_f) / range
      fsize = (0 + steps) * ratio
      tagcloud[tag.name] = fsize.round
    end
    return tagcloud
  end
end
