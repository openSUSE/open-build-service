
xml.tagcloud(:distribution_method => @distribution_method, :steps => @steps, :user => params[:user]) do  

  @tags.each do |tag|
    case @distribution_method
      when "raw"
        xml.tag(:name => CGI::escapeHTML(tag[0]), :count => tag[1])
      else
        xml.tag(:name => CGI::escapeHTML(tag[0]), :size => tag[1])
     end
   end

end
