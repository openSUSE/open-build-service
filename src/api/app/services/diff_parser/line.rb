class DiffParser
  class Line
    attr_reader :content, :state, :index, :original_index, :changed_index

    def initialize(content:, state:, index:, original_index:, changed_index:)
      @content = content
      @state = state
      @index = index
      @original_index = original_index
      @changed_index = changed_index
    end
  end
end
