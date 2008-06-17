require 'rexml/document'

# Stores two kinds of information: data and guesses
# wizard_state.data[key] reads or stores data
# wizard_state.guess[key] reads or stores guesses
# wizard_state.[key] returns data or guess
# wizard_state.dirty returns true if either data or guess were modified
# wizard_state.serialize stores data & guesses as XML
class WizardState
  class Table
    attr_reader(:dirty)

    def initialize(hash = {})
      @table = hash
      @dirty = false
    end

    def [](key)
      @table[key]
    end

    def []=(key, value)
      if @table[key] != value
        @table[key] = value
        @dirty = true
      end
    end

    def each(&block)
      @table.each(&block)
    end
  end

  attr_reader(:version, :data, :guess)

  def initialize(text = "")
    data = {}
    guess = {}
    xml = REXML::Document.new(text)
    xml.elements.each("wizard/data") do |element|
      data[element.attributes["name"]] = element.text
    end
    xml.elements.each("wizard/guess") do |element|
      guess[element.attributes["name"]] = element.text
    end
    @data = Table.new(data)
    @guess = Table.new(guess)
    @version = xml.root ? (xml.root.attributes["version"] || 0) : 0
    @version = @version.to_i
    @dirty = false
  end

  def version=(value)
    if @version != value
      @version = value
      @dirty = true
    end
  end

  def [](name)
    return @data[name] || @guess[name]
  end

  def dirty
    return @dirty || @data.dirty || @guess.dirty
  end

  def serialize
    xml = REXML::Document.new
    xml.add_element(REXML::Element.new("wizard"))
    xml.root.attributes["version"] = @version.to_s
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
