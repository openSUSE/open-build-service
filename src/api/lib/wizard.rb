require 'rexml/document'

class Wizard
  def self.guess_version(name, tarball)
    if tarball =~ /^#{name}-(.*)\.tar\.(gz|bz2)$/i
      return $1
    elsif tarball =~ /.*-([0-9\.]*)\.tar\.(gz|bz2)$/
      return $1
    end
    return nil
  end

  def initialize(text = nil)
    if !text || text.empty?
      @data = DirtyHash.new
      @guess = DirtyHash.new
      @version = 1
      @dirty = false
      return
    end

    data = {}
    guess = {}
    xml = REXML::Document.new(text)
    xml.elements.each("wizard/data") do |element|
      data[element.attributes["name"]] = element.text
    end
    xml.elements.each("wizard/guess") do |element|
      guess[element.attributes["name"]] = element.text
    end
    @data = DirtyHash.new(data)
    @guess = DirtyHash.new(guess)
    @version = xml.root ? (xml.root.attributes["version"] || 1) : 1
    @version = @version.to_i
    @dirty = false
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

  def dirty
    return @dirty || @data.dirty || @guess.dirty
  end

  def [](name)
    return @data[name] || @guess[name]
  end

  def []=(name, value)
    @data[name] = value
# to be removed
    case name
    when "name"
      if value =~ /^perl-/i
        @guess["packtype"] = "perl"
      elsif value =~ /^python-/i
        @guess["packtype"] = "python"
      end
    end
  end

  def run
    @questions = nil
    ask "name"
    return @questions if @questions
    ask "sourcefile"
    ask "generator"
    return @questions if @questions
    ask "summary"
    ask "description"
    return @questions if @questions
#    ask "license"
#    ask "group"
#    return @questions if @questions
    return nil
  end

  def generate_spec(template)
    erb = ERB.new(template)
    hb = HashBinding.new(@guess.merge(@data))
    template = erb.result(hb.getBinding)
  end

  private

  def ask(databit)
    if @data[databit]
      return
    end
    if ! @questions
      @questions = []
    end
    @questions << { databit => @@databits[databit] }
  end

  @@databits = {
    # note that the name is already known when running in the buildservice
    "name"        => {
      'type'  => "text",
      'label' => "Name of the package"
    },
    "sourcefile"  => {
      'type'  => "url",
      'label' => "Source file to download"
    },
    "generator"   => {
      'type'    => "select",
      'label'   => "Generate build description",
      'options' => [
# shall be requested from backend
        { "-" => { 'label' => "skip"} },
        { "qmake" => { 'label' => "qmake based code generator"} }
      ]
    },
    "summary"     => {
      'type'  => "text",
      'label' => "Short summary of the package"
    },
    "description" => {
      'type'  => "longtext",
      'label' => "Describe your package"
    },
    "license"     => {
      'type'  => "text",
      'label' => "License of the package"
    },
    "group"       => {
      'type'   => "text",
      'label'  => "Package group",
      'legend' => "See http://en.opensuse.org/SUSE_Package_Conventions/RPM_Groups"
    }
  }

  # hash that sets a dirty flag on write
  class DirtyHash < Hash
    attr_reader :dirty

    def initialize(h = {})
      replace(h)
    end

    def []=(key, value)
      if self[key] != value
        @dirty = true
        super(key, value)
      end
    end
  end

  # convert a hash into a binding, turning keys into instance variables
  class HashBinding
    def initialize(hash)
      hash.each do |key, value|
        if key !~ /^[a-zA-Z][a-zA-Z0-9_]*$/
          raise RuntimeError.new("Illegal key: #{key}")
        end
        instance_variable_set("@#{key}", value)
      end
    end

    def getBinding
      binding
    end
  end
end
