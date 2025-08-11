class EntraId::Hooks < Redmine::Hook::ViewListener
  render_on :view_users_form, partial: "users/entra_id_auth_info"
end
