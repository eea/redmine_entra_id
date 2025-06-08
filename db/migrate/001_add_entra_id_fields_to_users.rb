class AddEntraIdFieldsToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :oid, :string
    add_column :users, :synced_at, :datetime

    add_index :users, :oid, unique: true
  end
end
