class EntraId::SyncResult
  attr_reader :entra_user, :local_user, :operation, :status, :error

  OPERATIONS = %w[created updated deactivated skipped].freeze
  STATUSES = %w[success error].freeze

  def initialize(entra_user: nil, local_user: nil, operation:, status: "success", error: nil)
    @entra_user = entra_user
    @local_user = local_user
    @operation = operation
    @status = status
    @error = error
  end

  def success?
    status == "success"
  end

  def error?
    status == "error"
  end

  def created?
    @operation == "created"
  end

  def updated?
    @operation == "updated"
  end

  def summary
    data = {
      op: @operation,
      status: @status
    }

    data[:oid] = @entra_user.oid if created? || updated?
    data[:login] = created? ? entra_user.email : local_user.login
    data[:error] = error if error?

    data
  end

  def to_s
    summary.to_json
  end
end
