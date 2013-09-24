class Html::MainController < ApplicationController

  def index
    @messages = StatusMessage.alive
  end
end
