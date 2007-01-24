class ResultController < ApplicationController

  def initialize
    @basedir = DATA_DIRECTORY + "/result/"
  end

  def index
    render_text( "Results Index" )
  end

  def file
    platform = params[ :platform ]
    project = params[ :project ]
    file = params[ :file ]

    if ( !project || !file )
      render_text( "Error in URL to Results File" )
      return
    end

    base_path = @basedir + project + "/"
    if ( platform ) then base_path += platform + "/" end
    path = base_path + file

    # FIXME Return error message if illegal file name is given
    
    if request.get?
      if not File.exist? path
        if ( platform )
          s = ""
          xml = Builder::XmlMarkup.new( :target => s )
          xml.packageresult do
            xml.status( "code" => "notbuilt" ) do
              xml.summary( "Not built yet." )
            end
          end
          send_data s, :type => "text/xml", :disposition => "inline"
        else
          s = ""
          xml = Builder::XmlMarkup.new( :target => s )
          xml.projectresult do
            xml.status( "code" => "notbuilt" ) do
              xml.summary( "Not built yet." )
            end
          end
          send_data s, :type => "text/xml", :disposition => "inline"
        end
      else
        if path =~ /\.log/
          contenttype = "text/plain"
        else
          contenttype = "text/xml"
        end
        send_file path, :type => contenttype, :disposition => "inline"
      end
    end
  end
end
