xml.distributions do
  @distributions.each do |distribution|
    render(partial: 'distributions/distribution', locals: { distribution: distribution, builder: xml })
  end
end
