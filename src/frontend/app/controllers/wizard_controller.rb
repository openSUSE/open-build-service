require 'wizard'

class WizardController < ApplicationController

  # GET/POST /source/<project>/<package>/_wizard
  def package_wizard
    prj_name = params[:project]
    pkg_name = params[:package]
    pkg = DbPackage.find_by_project_and_name(prj_name, pkg_name)
    unless pkg
      render_error :status => 404, :errorcode => "unknown_package",
        :message => "unknown package '#{pkg_name}' in project '#{prj_name}'"
      return
    end
    if not @http_user.can_modify_package?(pkg)
      render_error :status => 403, :errorcode => "change_package_no_permission",
        :message => "no permission to change package"
      return
    end

    logger.debug("package_wizard, #{params.inspect}")

    @wizard_xml = "/source/#{prj_name}/#{pkg_name}/wizard.xml"
    begin
      @wizard = Wizard.new(backend_get(@wizard_xml))
    rescue ActiveXML::Transport::NotFoundError
      @wizard = Wizard.new("")
    end
    @wizard["name"] = pkg_name
    @wizard["email"] = @http_user.email
    
    loop do
      questions = @wizard.run
      logger.debug("questions: #{questions.inspect}")
      if ! questions || questions.empty?
        break
      end
      @wizard_form = WizardForm.new(
                        "Creating package #{pkg_name} in project #{prj_name}")
      questions.each do |question|
        name = question.keys[0]
        if params[name] && ! params[name].empty?
          @wizard[name] = params[name]
          next
        end
        attrs = question[name]
        @wizard_form.add_entry(name, attrs["type"], attrs["label"],
                               attrs["legend"], attrs["options"], @wizard[name])
      end
      if ! @wizard_form.entries.empty?
        return render_wizard
      end
    end

    if @wizard["created_spec"] == "true"
      @wizard_form = WizardForm.new("Nothing to do",
      "There is nothing I can do for you now. In the future, I will be able to help you updating your package or fixing build errors.")
      @wizard_form.last = true
      return render_wizard
    end
    package = Package.find(params[:package], :project => params[:project])
    # FIXME: is there a cleaner way to do it?
    package.data.elements["title"].text = @wizard["summary"]
    package.data.elements["description"].text = @wizard["description"]
    package.save
    specname = "#{params[:package]}.spec"
    spec = @wizard.generate_spec(File.read("#{RAILS_ROOT}/files/wizardtemplate.spec"))
    backend_put("/source/#{params[:project]}/#{params[:package]}/#{specname}", spec)
    @wizard["created_spec"] = "true"
    @wizard_form = WizardForm.new("Finished",
      "I created #{specname} for you. Please review it and adjust it to fit your needs.")
    @wizard_form.last = true
    render_wizard
  end

  private
  def render_wizard
    if @wizard.dirty
      backend_put(@wizard_xml, @wizard.serialize)
    end
    render :template => "wizard", :status => 200
  end
end

# vim:et:ts=2:sw=2
