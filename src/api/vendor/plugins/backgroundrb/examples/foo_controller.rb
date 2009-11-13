class FooController < ApplicationController
  layout :choose_layout
  def index
  end

  def mobile_action
    #render :layout => "mobile"
  end

  def start_worker
    MiddleMan.new_worker(:worker => :error_worker, :worker_key => :hello_world,:data => "wow_man")
    render :text => "worker starterd"
  end

  def stop_worker
    MiddleMan.worker(:error_worker,:hello_world).delete
    render :text => "worker deleted"
  end

  def invoke_worker_method
    worker_response = MiddleMan.worker(:hello_worker).say_hello(:arg => data)
    render :text => worker_response
  end

  def renew
    MiddleMan.worker(:hello_worker).async_load_policy(:arg => current_user.id)
    render :text => "method invoked"
  end

  def query_all_workers
    t_response = MiddleMan.query_all_workers
    running_workers = t_response.map { |key,value| "#{key} = #{value}"}.join(',')
    render :text => running_workers
  end

  def ask_result
    t_result = MiddleMan.worker(:hello_worker).ask_result(cache_key)
  end

  private
  def choose_layout
    if action_name == 'mobile_action'
      "mobile"
    else
      "foo"
    end
  end
end
