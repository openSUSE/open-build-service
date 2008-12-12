if @type == "package"
    xml.instruct!
    xml.tags(@type => @package.name, :project => @project.name, :title => CGI::escapeHTML(@package.title), :user => params[:user]) do
    @tags.each do |tag|
    xml.tag(:name => CGI::escapeHTML(tag.name))
 end
 end
else
    xml.instruct!
    xml.tags(@type => @project.name, :title => CGI::escapeHTML(@project.title), :user => params[:user]) do
    @tags.each do |tag|
      xml.tag(:name => CGI::escapeHTML(tag.name))
    end
    end
 end        
