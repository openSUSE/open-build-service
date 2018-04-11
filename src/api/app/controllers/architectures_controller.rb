# frozen_string_literal: true

require 'opensuse/validator'

class ArchitecturesController < ApplicationController
  validate_action index: { method: :get, response: :directory }
  validate_action show: { method: :get, response: :architecture }

  # GET /architecture
  # GET /architecture.xml
  def index
    @architectures = Architecture.all

    respond_to do |format|
      format.xml do
        builder = Builder::XmlMarkup.new(indent: 2)
        arch_count = 0
        xml = builder.directory(count: '@@@') do |directory|
          @architectures.each do |arch|
            # Add directory entry that survived filtering
            directory.entry(name: arch.name)
            arch_count += 1
          end
        end
        # Builder::XML doesn't allow setting attributes later on, thus the usage of a placeholder
        xml.gsub!(/@@@/, arch_count.to_s)
        render xml: xml
      end
    end
  end

  # GET /architecture/i386
  # GET /architecture/i386.xml
  def show
    required_parameters :id
    @architecture = Architecture.find_by_name(params[:id])
    unless @architecture
      render_error(status: 400, errorcode: 'unknown_architecture', message: "Architecture does not exist: #{params[:id]}") && return
    end

    respond_to do |format|
      format.xml do
        builder = Builder::XmlMarkup.new(indent: 2)
        xml = builder.architecture(name: @architecture.name)
        render xml: xml
      end
    end
  end
end
