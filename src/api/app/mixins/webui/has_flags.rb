module Webui::HasFlags
  def create_flag
    authorize main_object, :update?

    @flag = main_object.flags.new( status: params[:status], flag: params[:flag] )
    @flag.architecture = Architecture.find_by_name(params[:architecture])
    @flag.repo = params[:repository] unless params[:repository].blank?

    respond_to do |format|
      if @flag.save
        # FIXME: This should happen in Flag or even better in Project
        main_object.store
        format.html { redirect_to({ action: :repositories }) }
        format.js { render 'change_flag' }
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
        # FIXME: This should happen in Flag or even better in Project
        main_object.store
        format.html { redirect_to({ action: :repositories }) }
        format.js { render 'change_flag' }
      else
        format.json { render json: @flag.errors, status: :unprocessable_entity }
      end
    end
  end

  def remove_flag
    authorize main_object, :update?

    @flag = Flag.find(params[:flag])
    main_object.flags.destroy(@flag)
    @flag = @flag.dup
    @flag.status = @flag.default_status

    respond_to do |format|
      # FIXME: This should happen in Flag or even better in Project
      main_object.store
      format.html { redirect_to({ action: :repositories }) }
      format.js { render 'change_flag' }
    end
  end
end
