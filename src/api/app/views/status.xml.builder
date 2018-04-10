# frozen_string_literal: true
xml.status('code' => @errorcode) do
  xml.summary @summary
  if @exception
    xml.exception do
      xml.type(@exception.class.name)
      xml.message(@exception.message)
      xml.backtrace do
        @exception.backtrace.each do |line|
          xml.line(line)
        end
      end
    end
  end
  if @data
    @data.each do |name, value|
      xml.data(value, name: name)
    end
  end
end
