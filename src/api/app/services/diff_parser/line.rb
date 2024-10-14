class DiffParser
  class Line
    attr_reader :state, :index, :original_index, :changed_index
    attr_accessor :content

    def initialize(content:, state:, index:, original_index:, changed_index:)
      @content = content
      @state = state
      @index = index
      @original_index = original_index
      @changed_index = changed_index
    end

    def ==(other)
      content == other.content && state == other.state && index == other.index && original_index == other.original_index && changed_index == other.changed_index
    end
  end
end
