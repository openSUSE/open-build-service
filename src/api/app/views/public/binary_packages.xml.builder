xml.package project: @project.name, package: params[:package] do
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
