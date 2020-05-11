# NOTE: Folowing: https://github.com/jbox-web/ajax-datatables-rails#using-view-helpers
class Datatable < AjaxDatatablesRails::ActiveRecord
  extend Forwardable

  def initialize(params, opts = {})
    @view = opts[:view_context]
    super
  end
end
