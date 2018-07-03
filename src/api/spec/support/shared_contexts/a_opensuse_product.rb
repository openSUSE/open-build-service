RSpec.shared_context 'a opensuse product' do
  let(:opensuse_product) do
    <<-XML.strip_heredoc
      <?xml version="1.0" encoding="UTF-8"?>
      <productdefinition xmlns:xi="http://www.w3.org/2001/XInclude">
        <products>
          <product>
            <vendor>openSUSE</vendor>
            <name>openSUSE</name>
            <version>20180605</version>
            <release>0</release>
          </product>
        </products>
      </productdefinition>
    XML
  end
end
