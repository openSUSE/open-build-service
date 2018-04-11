
# frozen_string_literal: true

xml.packages do
  @packages.each do |_name, package|
    render(partial: 'package', locals: { builder: xml, package: package })
  end
end
