require 'date'

class DummyBuilder
  
  def initialize( project, project_meta_file )
    @project = project
    @project_meta_file = project_meta_file
  end

  def logger
    return RAILS_DEFAULT_LOGGER
  end
  
  def build
    logger.debug "BUILD: #{@project_meta_file}"
    
    rpm_path = DATA_DIRECTORY + "/rpm/"
    unless File.exists? rpm_path
      Dir.mkdir rpm_path
    end

    results_path = DATA_DIRECTORY + "/result/"
    unless File.exists? results_path
      Dir.mkdir results_path
    end
    
    project_path = @project + "/"

    unless File.exists? rpm_path + project_path
      Dir.mkdir rpm_path + project_path
    end
    unless File.exists? results_path + project_path
      Dir.mkdir results_path + project_path
    end

    @project_xml = REXML::Document.new( File.open( @project_meta_file ) )
    @project_xml.elements.each( "/project/target" ) do |target|
      @target_name = target.elements['platform'].attribute( "name" ).to_s
      @target = target

      logger.debug @target_name
      
      target_path = project_path + @target_name + "/"
      
      unless File.exists? rpm_path + target_path
        Dir.mkdir rpm_path + target_path
      end
      unless File.exists? results_path + target_path
        Dir.mkdir results_path + target_path
      end

      @project_xml.elements.each( "/project/package" ) do |package|
        @package_name = package.attribute( "name" ).to_s

        package_path = target_path + @package_name
        package_file_path = package_path + ".rpm"
        f = File.new( rpm_path + package_file_path, "w" )
        f.print "Built triggered by #{@project_meta_file}"
        f.close

        results_file_path = package_path + ".result"
        write_package_result( results_path + results_file_path )

        log_file_path = package_path + ".log"
        f = File.new( results_path + log_file_path, "w" )
        f.print Time.now
        f.close

      end

=begin
      targetresults_file_path = target_path + "result"
      f = File.new( results_path + targetresults_file_path, "w" )
      builder = Builder::XmlMarkup.new
      out = builder.result do
        builder.summary( "All RPMs up to date.")
      end
      f.print out
      f.close
=end
      
    end

    projectresults_file_path = project_path + "result"
    write_project_result( results_path + projectresults_file_path )

  end

  private
 
  #generates randomized project result xml and stores to passed file
  def write_project_result( path )
    logger.debug "writing project result file: #{path}"
    stat_codes = %w{built failed partiallyfailed}
    stat_summaries = {
      'built'   => 'All packages built.',
      'failed'  => 'All packages failed.',
      'partiallyfailed' => 'Some packages failed.'
    }
    
    File.open( path, 'w' ) do |f|
      builder = Builder::XmlMarkup.new
      out = builder.projectresult('project' => @project) do
        builder.date( Time.now.strftime("%Y%m%dT%H%M%SZ") )
        builder.status('code' => 'building') do
          builder.summary('Build in progress')
          %w{new scheduled built failed stopped}.each do |state|
            builder.packagecount( rand(9), 'state' => state )
          end
        end
        @project_xml.root.elements.each('target') do |target|
          builder.platformresult('platform' => target.elements['platform'].attributes['name']) do
            stat_code = stat_codes[rand(stat_codes.length)]
            stat_summary = stat_summaries[stat_code]
            
            builder.status('code'=>stat_code) do
              builder.summary( stat_summary )
            end
            target.elements.each('arch') do |arch|
              builder.archresult('arch' => arch.text) do
                builder.status('code' => stat_code) do
                  builder.summary( stat_summary )
                end
              end
            end
          end
        end
      end
      #logger.debug "out: #{out}"
      f.print out
    end
  end

  #generates randomized package result xml and stores to passed file
  def write_package_result( path )
    logger.debug "writing package result xml file: #{path}"
    package_xml = REXML::Document.new( File.open("#{DATA_DIRECTORY}/source/#{@project}/#{@package}/_meta") )
    f = File.open( path, "w" ) do |f|
      builder = Builder::XmlMarkup.new
      package_attribs = {
        'package' => @package_name,
        'project' => @project,
        'platform' => @target_name
      }
      out = builder.packageresult( package_attribs ) do
        builder.date( Time.now.strftime("%Y%m%dT%H%M%SZ") )
        builder.status('code' => 'building') do
          builder.summary('Build in progress.')
        end
        logger.debug "target: #{@target.inspect}"
        @target.elements.each('arch') do |arch|
          builder.archresult('arch' => arch.text) do
            builder.status('code' => 'building') do
              builder.summary('Build in progress.')
            end
          end
        end
      end
      f.print out
    end
  end
    
end
