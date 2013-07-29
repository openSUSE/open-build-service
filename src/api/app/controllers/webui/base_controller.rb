#require 'json/ext'
#include SearchHelper

class Webui::BaseController < ApplicationController
  skip_filter :validate_params
end
