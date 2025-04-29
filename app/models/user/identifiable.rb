module User::Identifiable
  extend ActiveSupport::Concern

  included do
    scope :by_login, ->(login) { where(login: login) }
    scope :by_email, ->(address) { joins(:email_addresses).merge(EmailAddress.by_address(address)) }

    scope :by_email_or_login, ->(identifier) { by_email(identifier).or(User.by_login(identifier)) }
  end
end
