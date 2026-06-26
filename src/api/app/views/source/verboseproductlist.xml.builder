xml.productlist(count: @products.count) do
  @products.map do |product|
    xml.product(name: product.name, originproject: product.package.project.name, originpackage: product.package.name) do
      xml.cpe product.cpe
      xml.version product.version
    end
  end
end
