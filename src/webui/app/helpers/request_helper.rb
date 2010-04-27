module RequestHelper

  def reqtype(req)
    if req.has_element? :action
      type = req.action.value :type
    else
      type = req.value :type
    end
    type = "chgdev" if type == "change_devel"
    type
  end

end
