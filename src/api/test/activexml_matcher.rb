
module NodeMatcher #:nodoc:
  class Conditions < Hash #:nodoc:
    def initialize(hash)
      super()
      hash = { content: hash } unless hash.is_a?(Hash)
      hash = keys_to_symbols(hash)
      hash.each do |k, v|
        case k
        when :tag, :content
          nil # keys are valid, and require no further processing
        when :attributes
          hash[k] = keys_to_strings(v)
        when :parent, :child, :ancestor, :descendant, :sibling, :before,
          :after
          hash[k] = Conditions.new(v)
        when :children
          hash[k] = v = keys_to_symbols(v)
          v.each do |key, value|
            case key
            when :count, :greater_than, :less_than
              nil # keys are valid, and require no further processing
            when :only
              v[key] = Conditions.new(value)
            else
              raise "illegal key #{key.inspect} => #{value.inspect}"
            end
          end
        else
          raise "illegal key #{k.inspect} => #{v.inspect}"
        end
      end
      update hash
    end

    private

    def keys_to_strings(hash)
      Hash[hash.keys.map { |k| [k.to_s, hash[k]] }]
    end

    def keys_to_symbols(hash)
      Hash[hash.keys.map do |k|
        raise "illegal key #{k.inspect}" unless k.respond_to?(:to_sym)
        [k.to_sym, hash[k]]
      end]
    end
  end

  # Returns +true+ if the node meets any of the given conditions. The
  # +conditions+ parameter must be a hash of any of the following keys
  # (all are optional):
  #
  # * <tt>:tag</tt>: the node name must match the corresponding value
  # * <tt>:attributes</tt>: a hash. The node's values must match the
  #   corresponding values in the hash.
  # * <tt>:parent</tt>: a hash. The node's parent must match the
  #   corresponding hash.
  # * <tt>:child</tt>: a hash. At least one of the node's immediate children
  #   must meet the criteria described by the hash.
  # * <tt>:ancestor</tt>: a hash. At least one of the node's ancestors must
  #   meet the criteria described by the hash.
  # * <tt>:descendant</tt>: a hash. At least one of the node's descendants
  #   must meet the criteria described by the hash.
  # * <tt>:sibling</tt>: a hash. At least one of the node's siblings must
  #   meet the criteria described by the hash.
  # * <tt>:after</tt>: a hash. The node must be after any sibling meeting
  #   the criteria described by the hash, and at least one sibling must match.
  # * <tt>:before</tt>: a hash. The node must be before any sibling meeting
  #   the criteria described by the hash, and at least one sibling must match.
  # * <tt>:children</tt>: a hash, for counting children of a node. Accepts the
  #   keys:
  # ** <tt>:count</tt>: either a number or a range which must equal (or
  #    include) the number of children that match.
  # ** <tt>:less_than</tt>: the number of matching children must be less than
  #    this number.
  # ** <tt>:greater_than</tt>: the number of matching children must be
  #    greater than this number.
  # ** <tt>:only</tt>: another hash consisting of the keys to use
  #    to match on the children, and only matching children will be
  #    counted.
  #
  # Conditions are matched using the following algorithm:
  #
  # * if the condition is a string, it must be a substring of the value.
  # * if the condition is a regexp, it must match the value.
  # * if the condition is a number, the value must match number.to_s.
  # * if the condition is +true+, the value must not be +nil+.
  # * if the condition is +false+ or +nil+, the value must be +nil+.
  #
  # Usage:
  #
  #   # test if the node is a "span" tag
  #   node.match :tag => "span"
  #
  #   # test if the node's parent is a "div"
  #   node.match :parent => { :tag => "div" }
  #
  #   # test if any of the node's ancestors are "table" tags
  #   node.match :ancestor => { :tag => "table" }
  #
  #   # test if any of the node's immediate children are "em" tags
  #   node.match :child => { :tag => "em" }
  #
  #   # test if any of the node's descendants are "strong" tags
  #   node.match :descendant => { :tag => "strong" }
  #
  #   # test if the node has between 2 and 4 span tags as immediate children
  #   node.match :children => { :count => 2..4, :only => { :tag => "span" } }
  #
  #   # get funky: test to see if the node is a "div", has a "ul" ancestor
  #   # and an "li" parent (with "class" = "enum"), and whether or not it has
  #   # a "span" descendant that contains # text matching /hello world/:
  #   node.match :tag => "div",
  #              :ancestor => { :tag => "ul" },
  #              :parent => { :tag => "li",
  #                           :attributes => { :class => "enum" } },
  #              :descendant => { :tag => "span",
  #                               :child => /hello world/ }
  def self.match(node, conditions)
    return false unless node

    case conditions
    when String
      return node.text == conditions
    when Regexp
      return node.text =~ conditions
    when Conditions
      nil
    else
      return false
    end
    # check content of child nodes
    if conditions[:content]
      if node.has_elements?
        # FIXME: This will always be falsy
        return false unless node.each { |child| match(child, conditions[:content]) }
      else
        return false unless match_condition(node.text, conditions[:content])
      end
    end

    # test the name
    if conditions[:tag]
      return false unless match_condition(node.element_name, conditions[:tag])
    end

    # test attributes
    (conditions[:attributes] || {}).each do |key, value|
      if value.nil?
        return false if node.has_attribute? key.to_s
      else
        return false unless node.has_attribute? key.to_s
        return false unless match_condition(node.value(key), value)
      end
    end

    # test parent
    if conditions[:parent]
      return false unless match(node.parent, conditions[:parent])
    end

    # test children
    if conditions[:child]
      found_one = false
      node.each do |child|
        found_one = match(child, conditions[:child])
        break if found_one
      end
      return false unless found_one
    end

    # test ancestors
    if conditions[:ancestor]
      return false unless catch :found do
        p = node.parent
        while p
          throw :found, true if match(p, conditions[:ancestor])
          p = p.parent
        end
      end
    end

    # test descendants
    if conditions[:descendant]
      found_one = false
      node.each do |child|
        # test the child
        found_one = match(child, conditions[:descendant]) ||
                    # test the child's descendants
                    match(child, descendant: conditions[:descendant])
        break if found_one
      end
      return false unless found_one
    end

    # count children
    opts = conditions[:children]
    if opts
      matches = Array.new
      node.each do |child|
        if opts[:only]
          matches << child if match(child, opts[:only])
        else
          matches << child
        end
      end

      opts.each do |key, value|
        next if key == :only
        case key
        when :count
          if value.is_a?(Integer)
            return false if matches.length != value
          else
            return false unless value.include?(matches.length)
          end
        when :less_than
          return false unless matches.length < value
        when :greater_than
          return false unless matches.length > value
        else raise "unknown count condition #{key}"
        end
      end
    end

    # test siblings
    if conditions[:sibling] || conditions[:before] || conditions[:after]
      siblings = []
      self_index = -1
      node.parent.each_with_index do |child, index|
        siblings << child
        self_index = index if child == node
      end
      raise 'homeless child!' unless self_index >= 0

      if conditions[:sibling]
        return false unless siblings.detect do |s|
          s != node && match(s, conditions[:sibling])
        end
      end

      if conditions[:before]
        return false unless siblings[self_index + 1..-1].detect do |s|
          s != node && match(s, conditions[:before])
        end
      end

      if conditions[:after]
        return false unless siblings[0, self_index].detect do |s|
          s != node && match(s, conditions[:after])
        end
      end
    end

    true
  end

  # Match the given value to the given condition.
  def self.match_condition(value, condition)
    case condition
    when Symbol
      value && value.to_s == condition.to_s
    when String
      value && value == condition
    when Regexp
      value && value.match(condition)
    when Numeric
      value == condition.to_s
    when true
      !value.nil?
    when false, nil
      value.nil?
    else
      false
    end
  end
end
