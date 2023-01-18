class SourcediffsParser
  def initialize(sourcediffs:)
    @sourcediffs = sourcediffs
  end

  def call
    @sourcediffs&.each do |sourcediff|
      sourcediff['filenames']&.each do |filename|
        next unless sourcediff['files'][filename].key?('diff')

        content = sourcediff['files'][filename]['diff']['_content']

        sourcediff['files'][filename]['diff']['parsed_lines'] = DiffParser.new(content: content).call
      end
    end
  end
end
