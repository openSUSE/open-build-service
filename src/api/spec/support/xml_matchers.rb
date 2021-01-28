RSpec::Matchers.define :have_xpath do |xpath|
  match do |str|
    Nokogiri::XML(str).xpath(xpath).any?
  end

  failure_message do |str|
    "Expected xpath #{xpath.inspect} to match in:\n" + Nokogiri::XML(str).to_xml(indent: 2)
  end

  failure_message_when_negated do |str|
    "Expected xpath #{xpath.inspect} not to match in:\n" + Nokogiri::XML(str).to_xml(indent: 2)
  end
end
