module EntraId
  class Hooks < Redmine::Hook::ViewListener
    # Add last sync time to user edit form
    render_on :view_users_form, partial: 'users/entra_id_auth_info'
  end
end