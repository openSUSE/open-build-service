module WorkflowInstrumentation
  extend ActiveSupport::Concern

  # Define callbacks with ActiveModel::Callback which is included in ActiveModel::Model
  included do
    define_model_callbacks :initialize, :call

    after_initialize :track_instantiation
    after_call :track_execution
    after_call :track_workflow_filters
  end

  private

  def track_instantiation
    RabbitmqBus.send_to_bus('metrics', 'workflow,action=instantiation count=1')
  end

  def track_execution
    RabbitmqBus.send_to_bus('metrics', "workflow,action=execution,default_configuration_path=#{token.workflow_configuration_path_default?}," \
                                       "using_configuration_url=#{token.workflow_configuration_url.present?} count=1")
  end

  def track_workflow_filters
    filters.each do |filter_key, _filter_value|
      RabbitmqBus.send_to_bus('metrics', "workflow,action=filter,filter=#{filter_key} count=1")
    end
  end
end
