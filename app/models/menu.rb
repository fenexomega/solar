class Menu < ActiveRecord::Base

  # auto-relacionamento
  has_many :children, :class_name => "Menu", :foreign_key => "parent_id"
  belongs_to :parent, :class_name => "Menu"

  # outros relacionamentos
  has_many :permissions_menus
  has_many :resources
  has_and_belongs_to_many :contexts

  # Lista com os menus do perfil do usuario dependendo do contexto
  def self.list_by_profile_id_and_context_id(profile_id, context_id)
    # consulta para recuperar os dados do menu
    query = "
      WITH cte_menus AS (
       SELECT DISTINCT
              t1.id    AS parent_id,
              t1.order AS parent_order,
              t1.name  AS parent,
              t2.id    AS child_id,
              t2.order AS child_order,
              t2.name  AS child,
              t2.resource_id
         FROM menus             AS t1                           -- menu pai
         JOIN menus             AS t2 ON (t2.parent_id = t1.id) -- menu filho
         JOIN permissions_menus AS t3 ON (t3.menu_id = t2.id) -- verifica permissoes aos menus filhos
        WHERE t2.status = TRUE AND t3.profile_id IN (#{profile_id}) -- permissoes para os menus filhos
      ), -- menus filhos com permissoes associadas
      --
      cte_all_parents AS (
          SELECT t1.id    AS parent_id,
                 t1.order AS parent_order,
                 t1.name  AS parent,
                 t3.child_order,
                 t3.child_id,
                 t3.child,
                 COALESCE(t3.resource_id, t1.resource_id) AS resource_id, -- resource do filho, senao do pai
                 t4.context_id,
                 t1.link
            FROM menus             AS t1 -- recuperando todos os menus-pai
            JOIN permissions_menus AS t2 ON (t2.menu_id = t1.id AND t1.parent_id IS NULL) -- verifica permissoes aos menus pais
       LEFT JOIN cte_menus         AS t3 ON (t3.parent_id = t1.id)
       LEFT JOIN menus_contexts    AS t4 ON (t4.menu_id = t1.id)
           WHERE t1.status = TRUE AND t2.profile_id IN (#{profile_id}) -- permissoes para os menus pais
      )
      SELECT DISTINCT ON (t1.parent_order, t1.child_order, t1.parent_id, t1.parent)
             t1.parent_id,
             t1.parent,
             t1.parent_order,
             t1.child,
             t1.child_order,
             t1.context_id,
             t1.resource_id,
             t2.controller,
             t2.action,
             t1.link
        FROM cte_all_parents  AS t1
   LEFT JOIN resources        AS t2 ON (t2.id = t1.resource_id)
       WHERE (t1.context_id = '#{context_id}' OR t1.context_id = #{Context_General})
         AND ((t1.resource_id IS NOT NULL AND t2.status = TRUE) OR (t1.resource_id IS NULL AND t1.child IS NULL)) -- verifica se o registro eh um pai ou nao
       ORDER BY t1.parent_order, t1.child_order, t1.parent_id, t1.parent;"

    menus = ActiveRecord::Base.connection.select_all query
    (menus.first.nil?) ? [] : menus
  end

end
