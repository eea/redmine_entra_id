module EmailAddress::Identifiable
  extend ActiveSupport::Concern

  included do
    scope :by_address, ->(address) { where(address: address) }
  end
end
