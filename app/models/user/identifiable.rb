module User::Identifiable
  extend ActiveSupport::Concern

  included do
    # EntraID-specific scopes
    scope :identified, -> { where.not(oid: nil) }
    scope :stale_since, ->(time) { where("synced_at IS NULL OR synced_at < ?", time) }


    alias_method :delete_unsafe_attributes_without_entra_id, :delete_unsafe_attributes
    alias_method :delete_unsafe_attributes, :delete_unsafe_attributes_with_entra_id
  end

  class_methods do
    def find_by_identity(identity)
      find_by(oid: identity.id) || find_by_mail(identity.email) || find_by_login(identity.email)
    end
  end

  def sync_with_identity(identity)
    update!(identity.to_user_params.except(:login, :mail))
    update_last_login_on!
  end

  def authenticated_via_entra?
    oid.present?
  end

  def delete_unsafe_attributes_with_entra_id(attrs, user = User.current)
    # Remove protected fields for Entra ID users
    if authenticated_via_entra?
      attrs = attrs.except("firstname", "lastname", "mail")
    end

    delete_unsafe_attributes_without_entra_id(attrs, user)
  end
end
