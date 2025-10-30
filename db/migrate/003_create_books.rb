class CreateBooks < ActiveRecord::Migration[7.0]
  def change
    create_table :books do |t|
      t.references :user, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: true
      t.string :title, null: false
      t.string :status, null: false, default: "to_read" # to_read, reading, finished
      t.integer :rating, null: false, default: 0
      t.timestamps
    end
    add_index :books, :status
    add_index :books, :title
  end
end


