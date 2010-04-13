module RequestHelper

  def reqtype(req)
    if req.has_element? :action
      type = req.action.method_missing(:type)
    else
      type = req.method_missing(:type)
    end
    type = "chgdev" if type == "change_devel"
    type
  end

end
