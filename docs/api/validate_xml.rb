#!/usr/bin/ruby

Dir.new( "." ).each do |e|
  if ( e =~ /(.*)\.xml$/ )
    system "xmllint -noout -schema #{$1}.xsd #{e}"
  end
end
