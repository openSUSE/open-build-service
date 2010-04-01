module RequestHelper
  def reqtype(req)
    type = req.action.method_missing(:type)
    if type == "change_devel"
      type = "chgdev"
    end
    type
  end
end
