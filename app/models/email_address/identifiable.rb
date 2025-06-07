module EmailAddress::Identifiable
  extend ActiveSupport::Concern

  included do
    scope :by_address, ->(address) { where("LOWER(address) = LOWER(?)", address) }
  end
end
