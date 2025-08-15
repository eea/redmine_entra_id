require File.expand_path("../../../test_helper", __FILE__)

module EntraId
  class IdentitiesControllerTest < ActionController::TestCase
    fixtures :users

    def setup
      @admin = users(:users_001) # Admin user
      @user = users(:users_002)  # Regular user
      # Set some EntraID data on the user
      @user.update!(oid: "test-oid-123", synced_at: Time.current)
    end

    test "removes the Entra OID and sync time from the account properties" do
      session[:user_id] = @admin.id # Log in as admin

      delete :destroy, params: { user_id: @user.id }

      assert_redirected_to edit_user_path(@user)
      assert_equal I18n.t(:notice_entra_id_identity_removed), flash[:notice]

      @user.reload
      assert_nil @user.oid
      assert_nil @user.synced_at
    end

    test "requires admin access to remove identity" do
      session[:user_id] = @user.id # Log in as regular user

      delete :destroy, params: { user_id: @user.id }

      assert_response :forbidden
      @user.reload
      assert_equal "test-oid-123", @user.oid
      assert_not_nil @user.synced_at
    end

    test "handles non-existent user" do
      session[:user_id] = @admin.id # Log in as admin

      delete :destroy, params: { user_id: 99999 }

      assert_response :not_found
    end
  end
end
