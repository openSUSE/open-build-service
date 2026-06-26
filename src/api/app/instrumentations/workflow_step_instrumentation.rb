module WorkflowStepInstrumentation
  extend ActiveSupport::Concern

  # Define callbacks with ActiveModel::Callback which is included in ActiveModel::Model
  included do
    define_model_callbacks :initialize

    after_initialize :track_instantiation
  end

  private

  def track_instantiation
    RabbitmqBus.send_to_bus('metrics', "workflow_step,step=#{self.class.name.demodulize.underscore},action=instantiation count=1")
  end
end
