#!/usr/bin/ruby.ruby3.4
# frozen_string_literal: true

require 'optparse'
require 'logger'
require 'yaml'
require 'json'
require 'json_refs'

class ResolveSwaggerYAML
  def initialize
    @log = Logger.new($stderr)
    parse_arguments
    check_for_file_existence
    resolved_yaml = resolve_swagger_yaml
    output_yaml_file(yaml_content: resolved_yaml)
  end

  private

  # rubocop:disable Metrics/MethodLength
  def parse_arguments
    opt_parser = OptionParser.new do |parser|
      parser.banner = 'Usage: resolve_swagger_yaml.rb [options]'
      parser.on('-i', '--input PATH/TO/SWAGGER.YAML', 'specify input swagger yaml file location') { |i| @input_file = i }
      parser.on('-o', '--output PATH/TO/SWAGGER.YAML', 'specify output location of resolved swagger yaml file') { |o| @output_file = o }
      parser.on('-f', '--force', 'allow overwrite of an existing file') { |f| @force = f }
      parser.on('-h', '--help', 'Print this help') do
        puts parser
        exit
      end
    end
    opt_parser.parse!(ARGV)
  end
  # rubocop:enable Metrics/MethodLength

  def check_for_file_existence
    return if File.file?(@input_file)

    @log.error("The specified input file does not exist: #{@input_file}")
    exit 1
  end

  def resolve_swagger_yaml
    yaml = Psych.unsafe_load(File.read(@input_file, encoding: Encoding::UTF_8))
    resolved_in_json_format = nil

    Dir.chdir(File.dirname(@input_file)) do
      # JsonRefs can handle the yaml format too, but returns a json formated version
      resolved_in_json_format = JsonRefs.call(yaml)
    end

    # Convert output back to yaml
    resolved_in_json_format.to_yaml
  end

  def output_yaml_file(yaml_content:)
    if File.file?(@output_file) && !@force
      @log.error("The file already exists, use '-f' to force overwrite: #{@output_file}")
      exit 1
    end

    File.write(@output_file, yaml_content)
  end
end

ResolveSwaggerYAML.new
