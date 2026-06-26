# This component shapes the input field, and it can be used in different places and different ways:
# - input box
# - input box with icon
# - input box with button
class InputComponent < ApplicationComponent
  renders_one :label
  renders_one :icon
  renders_one :button
end
