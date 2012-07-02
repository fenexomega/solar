include GroupAssignmentHelper

class GroupAssignmentsController < ApplicationController

  before_filter :prepare_for_group_selection #, :only => [:list]
  before_filter :user_related_to_assignment?, :except => [:index]
  before_filter :can_import?, :only => [:import_groups_page, :import_groups]
  load_and_authorize_resource

  # lista trabalhos em grupo
  def index
    #authorize! :list, Portfolio
    group_id = AllocationTag.find(active_tab[:url]['allocation_tag_id']).group_id

    #traz apenas os trabalhos de grupo dessa turma
    @assignments = GroupAssignment.all_by_group_id(group_id)
  end

  ##
  # Página de criação grupo
  # => @groups: todos os grupos da atividade
  # => @students_with_no_group: lista de alunos sem grupo
  ##
  def new
    @group_assignment = GroupAssignment.new(params[:group_assignment])
    @assignment = Assignment.find(params[:assignment_id])
    @groups = group_assignments(@assignment.id)
    @students_with_no_group = no_group_students(@assignment.id)
  end

  ##
  # Cria o grupo
  ##
  def create
    new_group_assignment = GroupAssignment.new(:assignment_id => params[:assignment_id], :group_name => params[:group_assignment][:group_name])
    
    if new_group_assignment.save
      change_students_group(new_group_assignment, params[:students_no_group])
      flash_msg = t(:group_assignment_success)
      flash_class = 'notice'
      redirect = group_assignments_url
      success = true
    else
      flash_msg = new_group_assignment.errors.full_messages[0]
      flash_class = 'alert'
      redirect = {:action => :new, :assignment_id => params[:assignment_id]}
      success = false
    end
 
    respond_to do |format|
      format.html { redirect_to(redirect, flash_class.to_sym => flash_msg) }
      format.xml  { render :xml => { :success => success } }
      format.json  { render :json => { :success => success, :flash_msg => flash_msg, :flash_class => flash_class } }
    end

  end

  ##
  # Página de edição de grupo
  # => @groups: todos os grupos da atividade
  # => @students_with_no_group: lista de alunos sem grupo
  ##
  def edit
    @group_assignment = GroupAssignment.find(params[:id])
    @groups = group_assignments(@group_assignment.assignment_id, @group_assignment.id)
    @students_with_no_group = no_group_students(@group_assignment.assignment_id)
  end

  ##
  # Edita o grupo
  ##
  def update
#transaction \/
    # verificação de erros
    # some_error = false
    # params['groups'].each { |group|
    #   unless group[1]['group_id'].nil?
    #     group_name = group[1]['group_name']['0']
    #     if group[1]['group_id'] == '0'
    #       group = GroupAssignment.new(:assignment_id => params[:assignment_id], :group_name => group_name)
    #       #   flash_msg = new_group_assignment.errors.full_messages[0]
    #       #   flash_class = 'alert'
    #       #   redirect = {:action => :new, :assignment_id => params[:assignment_id]}
    #       #   success = false
    #     else
    #       group = GroupAssignment.find(group[1]['group_id'].to_i)
    #       group.group_name = group_name
    #       #   flash_msg = group_assignment.errors.full_messages[0]
    #       #   flash_class = 'alert'
    #       #   redirect = {:action => :edit, :id => group_assignment.id, :assignment_id => group_assignment.assignment_id}
    #       #   success = false
    #     end
    #     some_error = !group.valid?
    #     break if some_error
    #   end
    # }
#transaction/\

    # criação/edição de grupos
    params['groups'].each { |group|
      group_id = group[1]['group_id']
      group_participants_ids = (group[1]['student_ids']).collect{|participant| participant[1].to_i} unless group[1]['student_ids'].nil?
      unless group_id.nil?
        group_name = group[1]['group_name']['0']
        # novo grupo
        if group_id == '0'
          group_assignment = GroupAssignment.create(:assignment_id => params[:assignment_id], :group_name => group_name)
        # grupo já existente
        else
          group_assignment = GroupAssignment.find(group_id)
          group_assignment.update_attributes(:group_name => group_name)
        end
      #alunos sem grupo
      else
        group_assignment = nil
      end
      change_students_group(group_assignment, group_participants_ids, params[:assignment_id])
    }

    #sucesso:

          #   flash_msg = t(:group_assignment_success)
          #   flash_class = 'notice'
          #   redirect = group_assignments_url
          #   success = true
          #   flash[flash_class] = flash_msg

      redirect_to group_assignments_url

    # edita
    # respond_to do |format|
    #   format.html { 
    #     flash[flash_class] = flash_msg unless success
    #     redirect_to(redirect) 
    #   }
    #   format.xml  { render :xml => { :success => success , :flash_msg => flash_msg, :flash_class => flash_class} }
    #   format.json  { render :json => { :success => success, :flash_msg => flash_msg, :flash_class => flash_class } }
    # end
    
      # cria
      # respond_to do |format|
      #   format.html { redirect_to(redirect, flash_class.to_sym => flash_msg) }
      #   format.xml  { render :xml => { :success => success } }
      #   format.json  { render :json => { :success => success, :flash_msg => flash_msg, :flash_class => flash_class } }
      # end

  end

  ##
  # Exclui o grupo
  ##
  def destroy
    group_assignment = GroupAssignment.find(params[:id])
    if SendAssignment.find_all_by_group_assignment_id(group_assignment.id).empty?
      participants = group_participants(group_assignment.id)
      participants.each{|participant| GroupParticipant.find(participant["id"]).destroy}
      GroupAssignment.find(group_assignment.id).destroy
      flash[:notice] = t(:group_assignment_delete_success)
      redirect_to group_assignments_url
    else
      flash[:alert] = t(:group_assignment_delete_error)
      redirect_to :action => :edit, :id => group_assignment.id, :assignment_id => group_assignment.assignment_id
    end
  end

  ##
  # Página de importação de grupos (lightbox)
  # => @assignments: todas as atividades da turma acessada pelo usuário no momento
  # => @assignment_id: a atividade que irá importar os grupos
  ##
  def import_groups_page
    group_id = AllocationTag.find(active_tab[:url]['allocation_tag_id']).group_id
    @assignments = GroupAssignment.all_by_group_id(group_id)
    @assignment_id = params[:assignment_id]
    render :layout => false
  end

  ##
  # Importação de grupos
  ##
  def import_groups
    import_from_assignment_id = params[:assignment_id_import_from]
    import_to_assignment_id = params[:assignment_id]

    groups_to_import = GroupAssignment.find_all_by_assignment_id(import_from_assignment_id)

    unless groups_to_import.empty?
      groups_to_import.each do |group_to_import|
        group_imported = GroupAssignment.create(:group_name => group_to_import.group_name, :assignment_id => import_to_assignment_id)
        group_participants_to_import = GroupParticipant.find_all_by_group_assignment_id(group_to_import.id)
        unless group_participants_to_import.empty?
          group_participants_to_import.each do |participant_to_import|
            GroupParticipant.create(:group_assignment_id => group_imported.id, :user_id => participant_to_import.user_id)
          end
        end
      end
    end

    flash[:notice] = t(:group_assignment_import_success)
    redirect_to group_assignments_url
  end

private
  
  ##
  # Método que realiza as mudanças de um grupo e realiza as trocas de alunos
  # => group_assingment: objeto do grupo_assignment a ser alterado/criado
  # => students: lista dos ids dos participantes do grupo passado
  ##
  def change_students_group(group_assignment, students_ids, assignment_id)
    unless students_ids.nil?
      students_ids.each{|student_id|
        group_participant = GroupParticipant.includes(:group_assignment).where("group_participants.user_id = ? AND group_assignments.assignment_id = ?",
                                                                               student_id, assignment_id).first
        unless group_assignment.nil?
          if group_participant.nil?
            GroupParticipant.create(:group_assignment_id => group_assignment.id, :user_id => student_id)
          elsif group_participant.group_assignment_id != group_assignment.id
            student_sent_files_to_other_group = !SendAssignment.where("send_assignments.user_id = ? AND send_assignments.group_assignment_id != ? AND 
                                                send_assignments.assignment_id = ?", student_id, group_assignment.id, assignment_id).empty?
            group_participant.update_attributes(:group_assignment_id => group_assignment.id) unless student_sent_files_to_other_group
          end
        else
          student_sent_files_to_some_group = !SendAssignment.where("send_assignments.user_id = ? AND send_assignments.assignment_id = ?", 
                                                                    student_id, assignment_id).empty?
          group_participant.delete unless student_sent_files_to_some_group
        end
      }
    end
  end


  # ##
  # # Método que realiza as mudanças de um grupo e realiza as trocas de alunos
  # # => group_assingment: objeto do grupo_assignment a ser alterado/criado
  # # => students: lista dos ids dos participantes do grupo passado
  # ##
  # def change_students_group2(group_assignment, students)
  #   groups = group_assignments(group_assignment.assignment_id)
  #   studens_with_no_group = no_group_students(group_assignment.assignment_id)
  #   group_assignment.group_name = params[:group_assignment][:group_name]
  #     for group in groups
  #       gp = group_participants(group["id"])
  #       for p in gp
  #         # se o participante em questão tiver sido selecionado
  #         if !students.nil? and students.include?(p["user_id"])
  #           # troca seu grupo
  #           participant = GroupParticipant.find(p["id"])
  #           participant.update_attribute(:group_assignment_id, group_assignment.id)
  #         end
  #         # se o grupo do participante em questão for o grupo que foi alterado E (nenhum aluno tiver sido selecionado OU o participante em questão não estiver incluso na lista de alunos) E o participante em questão não tiver enviado nenhum arquivo pelo grupo
  #         # remove o aluno do grupo
  #         GroupParticipant.find(p["id"]).delete if p["group_assignment_id"].to_i == group_assignment.id and (students.nil? or !students.include?(p["user_id"])) and SendAssignment.find_all_by_group_assignment_id_and_user_id(group_assignment.id, p["user_id"].to_i).empty?
  #       end
  #     end
  #     for no_group in studens_with_no_group
  #      GroupParticipant.create(:group_assignment_id => group_assignment.id, :user_id => no_group.id) if !students.nil? and students.include?(no_group.id.to_s)
  #     end
  # end

  # ##
  # # Método que cria a lista com os ids dos group_participants checkados de um determinado grupo (utilizado em update)
  # #
  # # Parameters:
  # # - group_id: id de cada grupo existente nas opções de escolha dos participantes
  # # - selected_students: recupera todos os ids dos group_participant dos estudantes selecionados de determinado grupo
  # ##
  # def create_list_checked_students(group_id, selected_students)

  #    list_checked_students = []
  #    # a menos que nenhum item tenha sido selecionado
  #     unless selected_students.nil?
  #       # selected students vem no formato: [{"grupo_id"=>"id do group_participant do aluno checado"}]
  #       # logo, o collect abaixo pega o valor do id do usuário do group_participant checado associado à cada grupo que existia nas opções
  #       list_checked_students = selected_students.collect{|student| GroupParticipant.find(student[group_id]).user_id.to_s unless student[group_id].nil?}
  #     end
  #     # retorna uma lista de ids referentes aos alunos marcados na página
  #     return list_checked_students
  # end

end