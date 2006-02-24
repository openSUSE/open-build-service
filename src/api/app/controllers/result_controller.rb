require 'rexml/document'

class ResultController < ApplicationController

  def index
    render_text( "Results Index" )
  end

  def projectresult
    @project = params[:project]

    response = Suse::Backend.get_project_result( @project )

    @repository_status = Hash.new
    
    result = REXML::Document.new( response.body ).root
    result.elements["/statussumlist"].elements.each do |s|
      status = s.attributes["status"]
      if status
        arch_name = s.attributes["name"]
        arch_name =~ /.*\/(.*)\/(.*)/
        repository = $1
        arch = $2
        if ( repository != ":all" )
          @arch_status = @repository_status[ repository ]
          if ( !@arch_status )
            @arch_status = Hash.new
          end
          @arch_status[ arch ] = status
          @repository_status[ repository ] = @arch_status        
        end

        if( repository == ":all" && arch == ":all" )
          @succeeded = s.attributes["succeeded"]
          @rpms = s.attributes["rpms"]
          @building = s.attributes["building"]
          @delayed = s.attributes["delayed"]
          @status = status
        end
      end
    end
    
  end

  def packageresult
    @project = params[:project]
    @repository = params[:platform]
    @package = params[:package]

    response = Suse::Backend.get_package_result( @project, @repository, @package )

    @arch_status = Hash.new
    @arch_rpms = Hash.new
    
    result = REXML::Document.new( response.body ).root
    result.elements["/statussumlist"].elements.each do |s|
      status = s.attributes["status"]
      if status
        arch_name = s.attributes["name"]
        arch_name =~ /.*\/.*\/(.*)/
        arch = $1
        @arch_status[ arch ] = status
        
        rpm_response = Suse::Backend.get_rpmlist( @project, @repository,
          @package, arch )
        rpms = Array.new
        rpm_result = REXML::Document.new( rpm_response.body ).root
        rpm_result.elements["/rpmlist"].elements.each do |r|
          rpms.push r.attributes["filename"]
        end
        
        @arch_rpms[ arch ] = rpms
        
      else
        @succeeded = s.attributes["succeeded"]
        @failed = s.attributes["failed"]
      end
    end
    
    if @failed == "0"
      @status = "suceeded"
    elsif @succeeded == "0"
      @status = "failed"
    else
      @status = "partiallyfailed"
    end
    
  end

  def log
    @project = params[:project]
    @repository = params[:platform]
    @package = params[:package]
    @arch = params[:arch]

    if( params[:nostream] )
      start = params[:start] or 0
      response = Suse::Backend.get_log_chunk( @project, @repository, @package, @arch, start )
    else
      response = Suse::Backend.get_log( @project, @repository, @package, @arch )
    end
    send_data( response.body, :type => "text/plain",
      :disposition => "inline" )
        
  end

end
