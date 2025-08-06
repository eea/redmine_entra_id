# frozen_string_literal: true

module EntraId::UserQueryPatch
  def self.included(base)
    base.class_eval do
      self.available_columns << QueryColumn.new(:oid, sortable: "#{User.table_name}.oid", caption: :field_entra_id_oid)
      self.available_columns << QueryColumn.new(:synced_at, sortable: "#{User.table_name}.synced_at", caption: :field_entra_id_synced_at)

      alias_method :initialize_available_filters_without_oid, :initialize_available_filters

      def initialize_available_filters
        initialize_available_filters_without_oid

        add_available_filter "oid", type: :string, label: :field_entra_id_oid
        add_available_filter "synced_at", type: :date, label: :field_entra_id_synced_at
      end
    end
  end
end
