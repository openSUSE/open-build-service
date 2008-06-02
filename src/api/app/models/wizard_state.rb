class WizardState

  attr_reader(:dirty)

  def initialize(text = "")
    @data = {}
    @guess = {}
    @dirty = false
    xml = REXML::Document.new(text)
    xml.elements.each("wizard/data") do |element|
      @data[element.attributes["name"]] = element.text
    end
    xml.elements.each("wizard/guess") do |element|
      @guess[element.attributes["name"]] = element.text
    end
  end

  def store(name, value)
    if @data[name] != value
      @data[name] = value
      @dirty = true
    end
  end

  def store_guess(name, value)
    if @guess[name] != value
      @guess[name] = value
      @dirty = true
    end
  end

  def get(name)
    return @data[name] || @guess[name]
  end

  def get_data(name)
    return @data[name]
  end

  def serialize
    xml = REXML::Document.new
    xml.add_element(REXML::Element.new("wizard"))
    @data.each do |name, value|
      e = REXML::Element.new("data")
      e.attributes["name"] = name
      e.text = value
      xml.root.add_element(e)
    end
    @guess.each do |name, value|
      e = REXML::Element.new("guess")
      e.attributes["name"] = name
      e.text = value
      xml.root.add_element(e)
    end
    res = ""
    xml.write(res)
    return res
  end

end

# vim:et:ts=2:sw=2
