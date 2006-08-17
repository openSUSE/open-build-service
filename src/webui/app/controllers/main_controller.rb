class MainController < ApplicationController
  skip_before_filter :authorize
end
