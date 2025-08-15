module EntraId
  class IdentitiesController < ApplicationController
    before_action :require_admin
    before_action :find_user

    def destroy
      if @user.update(oid: nil, synced_at: nil)
        flash[:notice] = l(:notice_entra_id_identity_removed)
      else
        flash[:error] = l(:error_entra_id_identity_removal_failed)
      end
      
      redirect_to edit_user_path(@user)
    end

    private

    def find_user
      @user = ::User.find(params[:user_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
