# This component accepts these parameters:
# - modal_id: it is compulsory and should be unique, you have to pass it to the component and you can not use the
#             same id in two different calls to the component.
# - method: (the method or verb we use when submitting the form) it is compulsory.
# - action: (URL we send the form to) you either pass it to the component or is '#' by default because we are going to set it by JavaScript.
# - modal_title and confirmation_text: they are optional. Pass them only if you want to overwrite the default texts.
# - remote: It is an optional parameter. If not provided, it's going to be false by default.

class DeleteConfirmationDialogComponent < ApplicationComponent
  attr_accessor :modal_id, :method, :action, :modal_title, :confirmation_text, :remote

  def initialize(modal_id:, method:, options: {})
    super

    @modal_id = modal_id
    @method = method
    @action = options[:action] || '#'
    @modal_title = options[:modal_title] || 'Do you really want to remove this item?'
    @confirmation_text = options[:confirmation_text] || 'Please confirm you want to remove this item.'
    @remote = options[:remote] || false
  end
end
