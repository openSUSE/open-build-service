# wizard input form with entries
class WizardForm

  attr_reader(:label, :legend, :entries)
  attr_accessor(:last)

  def initialize(label, legend="")
    @label = label
    @legend = legend
    @entries = []
  end

  class Entry
    attr_reader(:name, :type, :label, :legend, :value, :options)
    def initialize(name, type, label, legend, value, options=nil)
      @name = name
      @type = type
      @label = label
      @legend = legend
      @value = value
      @options = options
    end
  end

  def add_entry(name, type, label, legend="", value="")
    e = Entry.new(name, type, label, legend, value)
    @entries << e
  end

  def add_select_entry(name, type, label, legend, value, options)
    e = Entry.new(name, type, label, legend, value, options)
    @entries << e
  end

end

# vim:et:ts=2:sw=2
