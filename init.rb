Redmine::Plugin.register :entra_id do
  name "Entra ID"
  author "EEA"
  description "Enable login using Microsoft EntraID"
  version '0.0.1'
  url "https://github.com/eea/redmine_entra_id"
  author_url "https://github.com/eea/redmine_entra_id/graphs/contributors"

  settings default: {
    enabled: false,
    exclusive: false,
    client_id: "",
    client_secret: "",
    tenant_id: ""
  }, partial: "settings/entra_id"
end
