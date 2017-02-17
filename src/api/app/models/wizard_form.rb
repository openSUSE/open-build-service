# wizard input form with entries
class WizardForm
  attr_reader(:label, :legend, :entries)
  attr_accessor(:last)

  def initialize(label, legend = "")
    @label = label
    @legend = legend
    @entries = []
  end

  class Entry
    attr_reader(:name, :type, :label, :legend, :options, :value)
    def initialize(name, type, label, legend, options, value)
      @name = name
      @type = type
      @label = label
      @legend = legend
      @value = value

      return unless options

      @options = []
      options.each do |option|
        name = option.keys[0]
        attrs = option[name]
        e = Entry.new(name, nil, attrs["label"], attrs["legend"], nil, nil)
        @options << e
      end
    end
  end

  def add_entry(name, type, label, legend = nil, options = nil, value = nil)
    e = Entry.new(name, type, label, legend, options, value)
    @entries << e
  end
end

# vim:et:ts=2:sw=2
