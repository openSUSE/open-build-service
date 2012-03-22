# Be sure to restart your web server when you modify this file.

# Load the rails application
require File.expand_path('../application', __FILE__)

APIDOCS_LOCATION = File.expand_path("../../docs/api/html/")
SCHEMA_LOCATION = File.expand_path("public/schema")+"/"

ActionController::Base.perform_caching = true
#ActiveRbac.controller_layout = "rbac"

# Initialize the rails application
OBSApi::Application.initialize!

