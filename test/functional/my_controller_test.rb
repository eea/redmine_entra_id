# frozen_string_literal: true

require_relative "../test_helper"

class MyControllerTest < Redmine::IntegrationTest
  setup do
    @user = users(:users_002)
    log_user(@user.login, @user.login)
  end

  test "get account" do
    get '/my/account'
    assert_response :success
    assert_select 'form#my_account_form'
  end

  test "put account with regular user" do
    put '/my/account', :params => {
      :user => {
        :firstname => 'Joe',
        :lastname => 'Smith',
        :mail => 'jsmith@somenet.foo'
      }
    }

    @user.reload

    assert_redirected_to '/my/account'
    assert_equal 'Joe', @user.firstname
    assert_equal 'Smith', @user.lastname
    assert_equal 'jsmith@somenet.foo', @user.mail
  end

  test "put account with entra id user" do
    @user.update!(oid: 'entra-user-123')

    original_firstname = @user.firstname
    original_lastname = @user.lastname  
    original_mail = @user.mail

    put '/my/account', :params => {
      :user => {
        :firstname => 'Joe',
        :lastname => 'Smith',
        :mail => 'jsmith@somenet.foo',
        :language => 'fr'
      }
    }
    
    assert_redirected_to '/my/account'
    @user.reload
    
    # Name and email should remain unchanged
    assert_equal original_firstname, @user.firstname, "firstname should not be updated for Entra ID user"
    assert_equal original_lastname, @user.lastname, "lastname should not be updated for Entra ID user"
    assert_equal original_mail, @user.mail, "mail should not be updated for Entra ID user"
    
    # Other fields should be updatable
    assert_equal 'fr', @user.language
  end

  test "get account with entra id user" do
    @user.update!(oid: 'entra-user-123')
    
    get '/my/account'

    assert_response :success
    assert_select 'input[name="user[firstname]"][readonly="readonly"][disabled="disabled"]'
    assert_select 'input[name="user[lastname]"][readonly="readonly"][disabled="disabled"]'
    assert_select 'input[name="user[mail]"][readonly="readonly"][disabled="disabled"]'
    assert_select '.info', :text => /managed by your organization/
  end

  test "get account with regular user" do
    get '/my/account'

    assert_response :success
    assert_select 'input[name="user[firstname]"]:not([readonly])'
    assert_select 'input[name="user[lastname]"]:not([readonly])'
    assert_select 'input[name="user[mail]"]:not([readonly])'
    assert_select '.info', :text => /managed by your organization/, :count => 0
  end

  test "password link with entra id user" do
    @user.update!(oid: 'entra-user-123')
    
    get '/my/account'

    assert_response :success
    assert_select 'a[href="/my/password"]', 0
  end

  test "password link with regular user" do
    get '/my/account'

    assert_response :success
    assert_select 'a[href="/my/password"]'
  end
end
