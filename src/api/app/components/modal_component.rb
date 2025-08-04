class ModalComponent < ApplicationComponent
  renders_one :header
  renders_one :footer

  def initialize(modal_id:, modal_button_data: {})
    super

    @modal_id = modal_id
    @modal_button_data = modal_button_data
  end

  def button
    return if @modal_button_data.empty?

    render(ButtonComponent.new(type: @modal_button_data[:type] || 'secondary',
                               text: @modal_button_data[:text],
                               icon_type: @modal_button_data[:icon],
                               button_data: { 'bs-toggle': 'modal',
                                              'bs-target': "##{@modal_id}-modal" }))
  end
end
