require_relative '../test_helper'
require 'find'

class SchemaTest < ActiveSupport::TestCase
  test 'schemas' do
    Find.find(CONFIG['schema_location']).each do |f|
      io = nil
      case f
      when %r{\.rng$}
        testfile = f.gsub(%r{\.rng$}, '.xml')
        io = IO.popen("xmllint --noout --relaxng #{f} #{testfile} 2>&1 > /dev/null", 'r') if File.exist?(testfile)
      when %r{xsd}
        testfile = f.gsub(%r{\.xsd$}, '.xml')
        io = IO.popen("xmllint --noout --schema #{f} #{testfile} 2>&1 > /dev/null", 'r') if File.exist?(testfile)
      end
      next unless io

      testresult = io.read
      io.close
      assert $CHILD_STATUS == 0, "#{testfile} does not validate against #{f} -> #{testresult}"
    end
  end
end
