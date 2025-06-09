# frozen_string_literal: true

module EntraId::UserQueryPatch
  def self.included(base)
    base.class_eval do
      # Add OID column to available columns
      self.available_columns << QueryColumn.new(:oid, sortable: "#{User.table_name}.oid", caption: :field_entra_id_oid)

      # Override initialize_available_filters to add OID filter
      alias_method :initialize_available_filters_without_oid, :initialize_available_filters

      def initialize_available_filters
        initialize_available_filters_without_oid
        add_available_filter "oid", type: :string, label: :field_entra_id_oid
      end
    end
  end
end
