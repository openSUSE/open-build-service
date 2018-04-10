# frozen_string_literal: true

comments.each do |c|
  c.to_xml(builder)
end
