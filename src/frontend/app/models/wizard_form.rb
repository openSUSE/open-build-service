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
    attr_reader(:name, :type, :label, :legend, :value)
    def initialize(name, type, label, legend, value)
      @name = name
      @type = type
      @label = label
      @legend = legend
      @value = value
    end
  end

  def add_entry(name, type, label, legend="", value="")
    e = Entry.new(name, type, label, legend, value)
    @entries << e
  end

end

# vim:et:ts=2:sw=2
