require 'rails_helper'

RSpec.describe Webui::PackageHelper, type: :helper do
  describe '#nbsp' do
    it 'produces a SafeBuffer' do
      sanitized_string = nbsp("a")
      expect(sanitized_string).to be_a(ActiveSupport::SafeBuffer)
    end

    it 'escapes html' do
      sanitized_string = nbsp('<b>unsafe<b/>')
      expect(sanitized_string).to eq('&lt;b&gt;unsafe&lt;b/&gt;')
    end

    it 'converts space to nbsp' do
      sanitized_string = nbsp("my file")
      expect(sanitized_string).to eq('my&nbsp;file')
    end

    it 'breaks up long strings' do
      long_string = "a"*50 + "b"*50 + "c"*10
      sanitized_string = nbsp(long_string)
      assert_equal long_string.scan(/.{1,50}/).join("<wbr>"), sanitized_string
    end
  end
end
