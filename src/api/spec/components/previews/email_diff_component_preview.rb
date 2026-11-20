class EmailDiffComponentPreview < ViewComponent::Preview
  # Preview at http://HOST:PORT/rails/view_components/email_diff_component/preview
  def preview
    diff = <<~DIFF
      --- hello.spec
      +++ hello.spec
      @@ -1,6 +1,6 @@
       Name:           hello
      -Version:        2.10
      +Version:        2.12
       Release:        0
       Summary:        A friendly greeting program
      -License:        GPL-2.0
      +License:        GPL-3.0-or-later
       Group:          Development/Tools/Other
    DIFF
    render(EmailDiffComponent.new(diff: diff))
  end
end
