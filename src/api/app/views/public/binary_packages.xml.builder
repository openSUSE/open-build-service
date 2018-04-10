# frozen_string_literal: true

xml.package project: @pkg.project.name, package: @pkg.name do
  xml.title @pkg.title
  xml.description @pkg.description
  xml.binaries do
    @binary_links.each do |repo, arr|
      xml.list(distribution: repo) do
        xml.ymp arr[:ymp] if arr[:ymp]
        xml.repository arr[:repository] if arr[:repository]
        if arr[:binary]
          arr[:binary].each do |bin|
            binary_type = bin.delete(:type).to_sym
            xml.method_missing(binary_type, bin)
          end
        end
      end
    end
  end
end
