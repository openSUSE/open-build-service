module Webui::HasFlags
  def create_flag
    authorize main_object, :update?

    @flag = main_object.flags.new( status: params[:status], flag: params[:flag] )
    @flag.architecture = Architecture.find_by_name(params[:architecture])
    @flag.repo = params[:repository] unless params[:repository].blank?

    respond_to do |format|
      if @flag.save
        format.js
      else
        format.json { render json: @flag.errors, status: :unprocessable_entity }
      end
    end
  end

  def toggle_flag
    authorize main_object, :update?

    @flag = Flag.find(params[:flag])
    @flag.status = @flag.status == 'enable' ? 'disable' : 'enable'

    respond_to do |format|
      if @flag.save
        format.js
      else
        format.json { render json: @flag.errors, status: :unprocessable_entity }
      end
    end
  end

  def remove_flag
    authorize main_object, :update?

    @flag = Flag.find(params[:flag])
    @project.flags.destroy(@flag)

    respond_to do |format|
      format.js
    end
  end
end
