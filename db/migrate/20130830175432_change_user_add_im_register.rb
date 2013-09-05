class ChangeUserAddImRegister < ActiveRecord::Migration
  def change
    change_table :users do |t|
      t.boolean :im_register, default: false
    end
  end
end
