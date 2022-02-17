module WorkflowInstrumentation
  extend ActiveSupport::Concern

  # Define callbacks with ActiveModel::Callback which is included in ActiveModel::Model
  included do
    define_model_callbacks :initialize, :call

    after_initialize :track_instantiation
    after_call :track_execution
  end

  private

  def track_instantiation
    RabbitmqBus.send_to_bus('metrics', 'workflow,action=instantiation count=1')
  end

  def track_execution
    RabbitmqBus.send_to_bus('metrics', 'workflow,action=execution count=1')
  end
end
