class RpmLintComponentPreview < ViewComponent::Preview
  def preview
    content = Rack::Test::UploadedFile.new('spec/fixtures/files/rpmlint.log')
    parsed_messages = RpmlintLogParser.new(content: content).call
    render(RpmLintComponent.new(rpmlint_log_parser: parsed_messages))
  end

  def no_errors
    # Don't plot anything
    parsed_messages = RpmlintLogParser.new(content: '').call
    render(RpmLintComponent.new(rpmlint_log_parser: parsed_messages))
  end
end
