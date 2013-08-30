require 'event'

class EventsController < ApplicationController

  skip_before_action :extract_user, :only => [:create]
  skip_before_action :validate_xml_request
  skip_before_action :validate_params

  class UnknownEventType < APIException
    setup 400
  end

  def create
    required_parameters :eventtype, :time
    type = params.delete :eventtype
    event = EventFactory.new_from_type(type, params)
    raise UnknownEventType.new "#{type} is not known" unless event   
    event.save!
    render json: {status: "ok"}
  end
end

