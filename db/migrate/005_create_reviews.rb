class CreateReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :reviews do |t|
      t.references :book, null: false, foreign_key: true
      t.text :body, null: false
      t.integer :rating, null: false, default: 0
      t.timestamps
    end
  end
end


