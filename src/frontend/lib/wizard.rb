require 'rexml/document'

class Wizard
  def initialize(text = nil)
    if ! text || text.empty?
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
    case name
    when "name":
      if value =~ /^perl-/i
        @guess["packtype"] = "perl"
      elsif value =~ /^python-/i
        @guess["packtype"] = "python"
      end
    when "tarball":
      version = Wizard.guess_version(@data["name"], value)
      if version
        @guess["version"] = version
      end
    when "packtype":
      case value
      when "perl"
        @guess["license"] = "Artistic license"
        @guess["group"] = "Development/Libraries/Perl"
      when "python"
        @guess["license"] = "GPL v2 or later"
        @guess["group"] = "Development/Libraries/Python"
      else
        @guess["license"] = "GPL v2 or later"
        @guess["group"] = "Productivity/Other"
      end
    end
  end

  def run
    @questions = nil
    ask "name"
    return @questions if @questions
    ask "tarball"
    ask "packtype"
    return @questions if @questions
    ask "summary"
    ask "description"
    ask "version"
    ask "license"
    ask "group"
    ask "email"
    return @questions if @questions
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
      'type'    => "text",
      'label'   => "Name of the package",
    },
    "tarball"     => {
      'type'    => "file",
      'label'   => "Source tarball to upload",
    },
    "packtype"    => {
      'type'    => "select",
      'label'   => "What kind of package is this?",
      'options' => [
        { "generic" => { 'label' => "Generic (./configure && make)"} },
        { "perl"    => { 'label' => "Perl module"} },
        { "python"  => { 'label' => "Python module"} },
      ],
    },
    "version"     => {
      'type'    => "text",
      'label'   => "Version of the package",
      'legend'  => "Note that the version must not contain dashes (-)",
    },
    "summary"     => {
      'type'    => "text",
      'label'   => "Short summary of the package",
    },
    "description" => {
      'type'    => "longtext",
      'label'   => "Describe your package",
    },
    "license"     => {
      'type'    => "text",
      'label'   => "License of the package",
    },
    "group"       => {
      'type'    => "text",
      'label'   => "Package group",
      'legend'  => "See http://en.opensuse.org/SUSE_Package_Conventions/RPM_Groups",
    },
    "email"       => {
      'type'    => "text",
      'label'   => "Your email",
    },
  }

  public
  def self.guess_version(name, tarball)
      if tarball =~ /^#{name}-(.*)\.tar\.(gz|bz2)$/i
        return $1
      elsif tarball =~ /.*-([0-9\.]*)\.tar\.(gz|bz2)$/
        return $1
      end
      return nil
  end

  private
  # hash that sets a dirty flag on write
  class DirtyHash < Hash
    attr_reader :dirty

    def initialize(h = {})
      replace(h)
    end

    def []=(key,value)
      if self[key] != value
        @dirty = true
        super(key,value)
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

# vim:et:ts=2:sw=2
