require_dependency 'application'

# All controllers in ActiveRBAC extend this controller. Currently, it only
# provides the method config to access ActiveRBAC's configuration.
class ActiveRbac::ComponentController < ApplicationController
  model :user, :role, :group, :static_permission
  helper :rbac
end