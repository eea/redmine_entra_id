module User::Identifiable
  extend ActiveSupport::Concern

  included do
    scope :by_login, ->(login) { where("LOWER(login) = LOWER(?)", login) }
    scope :by_email, ->(address) { joins(:email_addresses).merge(EmailAddress.by_address(address)) }

    scope :by_email_or_login, ->(identifier) { by_email(identifier).or(User.by_login(identifier)) }

    scope :not_admin, -> { where(admin: false) }
    scope :identified, -> { where.not(oid: nil) }
    scope :stale_since, ->(time) { where("synced_at IS NULL OR synced_at < ?", time) }
  end

  class_methods do
    def find_by_identity(identity)
      user = find_by(oid: identity.id)
      user.present? ? user : by_email_or_login(identity.preferred_username).first
    end
  end

  def sync_with_identity(identity)
    update!(identity.to_user_params.except(:login, :mail))
  end

  def entra_id_authenticated?
    oid.present?
  end
end
