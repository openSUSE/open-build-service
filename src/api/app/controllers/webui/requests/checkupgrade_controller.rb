module Webui
  module Requests
    class CheckupgradeController < Webui::RequestController
      
      before_action :require_login
      before_action :set_package
      before_action :set_project
      after_action :verify_authorized, only: [:new, :create]

      def new
        @packageCheckUpgrade = PackageCheckUpgrade.find_by(package_id: @package.id)
        if ! @packageCheckUpgrade
          @packageCheckUpgrade = PackageCheckUpgrade.new
        end
        authorize @packageCheckUpgrade, :new?

        if @packageCheckUpgrade.state == PackageCheckUpgrade::STATE_ERROR 
          flash.now[:error] = 'An error has occurred'
        end
      end

      def create
        flash.clear

        #Get action
        @create_action = params[:commit] == 'Create' ? true : false
        @delete_action = params[:commit] == 'Delete' ? true : false
        @update_action = params[:commit] == 'Update' ? true : false

        if @delete_action
          @packageCheckUpgrade = PackageCheckUpgrade.find_by(id: params[:packageCheckUpgrade][:id])
        else
          @packageCheckUpgrade = PackageCheckUpgrade.new(packageCheckUpgrade_params)
          @packageCheckUpgrade.user_email = User.session.email
        end
        authorize @packageCheckUpgrade, :create?

        #Skip these steps only for delete action
        if ! @delete_action
          execute_check(@packageCheckUpgrade)
        end

        #Respond
        respond_to do |format|
          if @delete_action
            if !@packageCheckUpgrade.destroy  
              format.js { flash.now[:error] = 'An error has occurred' }
            else
              format.js { flash[:success] = 'Check upgrade deleted successfully' }
            end
          else
            if @packageCheckUpgrade.state == PackageCheckUpgrade::STATE_ERROR or 
              (@create_action and !@packageCheckUpgrade.save) or (@update_action and ! update_table?(@packageCheckUpgrade))
              format.js { flash.now[:error] = 'An error has occurred' }
            else
              if @create_action
                format.js { flash[:success] = 'Check upgrade created successfully' }
              elsif @update_action
                format.js { flash[:success] = 'Check upgrade updated successfully' }
              end
            end    
          end
          format.js {}
        end
      end

      private

      def packageCheckUpgrade_params
        params.require(:packageCheckUpgrade).permit(:id, :package_id, :urlsrc, :regexurl, :regexver, :currentver, 
            :separator, :output, :state, :send_email)
      end

      def update_table?(packageCheckUpgrade)        
        #Serialize the access on the record to avoid eventual race condition with background job
        @packageCheckUpgrade_db = PackageCheckUpgrade.lock.find_by(id: packageCheckUpgrade.id)
        if ! @packageCheckUpgrade_db
          return false
        else
          if @packageCheckUpgrade_db.update(urlsrc: packageCheckUpgrade.urlsrc,
              regexurl: packageCheckUpgrade.regexurl, regexver: packageCheckUpgrade.regexver,
              currentver: packageCheckUpgrade.currentver, separator: packageCheckUpgrade.separator,
              output: packageCheckUpgrade.output, state: packageCheckUpgrade.state, 
              send_email: packageCheckUpgrade.send_email)
            return true
          else
            return false
          end
        end
      end

      def execute_check(packageCheckUpgrade)
        result = packageCheckUpgrade.run_checkupgrade(User.session.login)
        #Set the output and state by result
        packageCheckUpgrade.set_output_and_state_by_result(result)
      end

    end
  end
end