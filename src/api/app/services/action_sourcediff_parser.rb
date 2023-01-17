class ActionSourcediffParser
  def initialize(action_sourcediff:)
    @action_sourcediff = action_sourcediff
  end

  def call
    @action_sourcediff&.each do |sourcediff|
      sourcediff['filenames']&.each do |filename|
        content = sourcediff['files'][filename].dig('diff', '_content')

        sourcediff['files'][filename]['diff']['parsed_lines'] = DiffParser.new(content: content).call
      end
    end
  end
end
