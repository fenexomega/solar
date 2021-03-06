class AllocationsController < ApplicationController
  include AllocationsHelper

  layout false, :except => [:index]

  authorize_resource :except => [:destroy, :designates, :create_designation, :activate, :deactivate]

  # GET /allocations/designates
  # GET /allocations/designates.json
  def designates
    @allocation_tags_ids  = params[:allocation_tags_ids].split(" ")

    begin    
      # verifica permissao de acessar alocacao das allocation tags passadas
      authorize! :designates, Allocation, on: @allocation_tags_ids
      
      level        = (params[:permissions] != "all") ? "responsible" : nil
      level_search = level.nil? ? ("not(profiles.types & #{Profile_Type_Student})::boolean and not(profiles.types & #{Profile_Type_Basic})::boolean") : ("(profiles.types & #{Profile_Type_Class_Responsible})::boolean")
      
      @allocations = Allocation.all(
        :joins => [:profile, :user], 
        :conditions => ["#{level_search} and allocation_tag_id IN (#{@allocation_tags_ids.join(",")}) "],
        :order => ["users.name", "profiles.name"]) 
    rescue CanCan::AccessDenied
      render json: {success: true, alert: t(:no_permission)}, status: :unprocessable_entity
    rescue ActiveRecord::AssociationTypeMismatch
      render json: {success: false, alert: t(:not_associated)}, status: :unprocessable_entity
    rescue 
      respond_to do |format|
        format.html { render :nothing => true, :status => 500 }
      end
    end
  end

  # Método, chamado por ajax, para buscar usuários para alocação
  def search_users
    text                 = URI.unescape(params[:user])
    @text_search         = text
    @allocation_tags_ids = params[:allocation_tags_ids].split(" ")
    @users               = User.where("lower(name) ~ '#{text.downcase}'")
  end

  # GET /allocations/enrollments
  # GET /allocations/enrollments.json
  def index
    groups = current_user.groups.map(&:id)
    p = params.select { |k, v| ['offer_id', 'group_id', 'status'].include?(k) }
    p['group_id'] = (params.include?('group_id') and groups.include?(params['group_id'].to_i)) ? [params['group_id']] : groups.flatten.compact.uniq

    @allocations = Allocation.enrollments(p)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @allocations }
    end
  end

  # GET /allocations/1
  # GET /allocations/1.json
  def show
    @allocation = Allocation.find(params[:id])
    respond_to do |format|
      format.html
      format.json { render json: @allocation }
    end
  end

  # GET /allocations/1/edit
  def edit
    @allocation   = Allocation.find(params[:id])
    @status_hash  = status_hash_of_allocation(@allocation.status)
    @change_group = (not [Allocation_Cancelled, Allocation_Rejected].include?(@allocation.status))

    # transicao entre grupos apenas da mesma oferta
    @groups       = @change_group ? Group.where(:offer_id => @allocation.group.offer_id) : @allocation.group
  end
  
  # Usado na matrícula
  def create
    profile = Profile.student_profile
    status  = Allocation_Pending
    allocation_tag = AllocationTag.find(params[:allocation_tag_id])
    offer   = allocation_tag.offer || allocation_tag.group.offer
    ok      = (offer.enrollment_start_date.to_date..(offer.enrollment_end_date.try(:to_date) || offer.end_date.to_date)).include?(Date.today)
    ok      = allocate(params[:allocation_tag_id], params[:user_id], profile, status, params[:id]) if ok
    message = ok ? ['notice', 'success'] : ['alert', 'error']
    respond_to do |format|
      format.html { redirect_to(enrollments_url, message.first.to_sym => t(:enrollm_request, :scope => [:allocations, message.last.to_sym])) }
    end
  end

  # Usado na alocacao de usuarios
  def create_designation
    allocation_tags_ids = params[:allocation_tags_ids].split(" ")

    begin 
      allocation_tags = AllocationTag.where(id: allocation_tags_ids)
      raise ActiveRecord::AssociationTypeMismatch if allocation_tags.map(&:group).empty? and allocation_tags.map(&:offer).empty?

      # verifica permissao de alocacao nas allocation tags passadas
      authorize! :create_designation, Allocation, on: allocation_tags_ids.flatten

      profile = (params.include?(:profile)) ? params[:profile] : Profile.student_profile
      status  = (params.include?(:status)) ? params[:status] : Allocation_Pending
      ok      = allocate(allocation_tags_ids, params[:user_id], profile, status)

      respond_to do |format|
        format.html { render :designates, status: (ok ? 200 : :unprocessable_entity) } 
      end
    rescue
      respond_to do |format|
        format.html { render :designates, status: :unprocessable_entity } 
      end      
    end

  end

  # PUT /allocations/1
  # PUT /allocations/1.json
  def update
    # authorize! :update, Allocation #.find(params[:id]) [authorize pelo authorize_resources]

    @allocation       = Allocation.find(params[:id])
    allocation_tag_id = (params.include?(:allocation) and params[:allocation].include?(:group_id)) ? Group.find(params[:allocation][:group_id]).allocation_tag.id : nil
    allocations       = Allocation.find(params[:id].split(','))
    allocation        = allocations.first
    new_status        = params.include?(:enroll) ? Allocation_Activated.to_i : ((params.include?(:allocation) and params[:allocation].include?(:status)) ? params[:allocation][:status] : 0)

    # verifica se existe mudanca de turma
      # se sim, todas as alocacoes serao canceladas e serao criadas novas com a nova turma
      # se não, somente o status das alocacoes serao modificados

    error = false
    begin
      ActiveRecord::Base.transaction do
        # mudanca de turma, nao existe chamada multipla para esta funcionalidade
        if ((not params.include?(:multiple)) and (not allocation_tag_id.nil?) and (allocation_tag_id != allocations.first.allocation_tag_id))
          # criando novas alocacoes e cancelando as antigas
          @allocation = Allocation.create!({:user_id => allocation.user_id, :allocation_tag_id => allocation_tag_id, :profile_id => allocation.profile_id, :status => params[:allocation][:status]})
          allocation.update_attributes(:status => Allocation_Cancelled) # cancelando a anterior

          Notifier.enrollment_accepted(@allocation.user.email, @allocation.group.code_semester).deliver if params[:allocation][:status].to_i == Allocation_Activated.to_i
        else # sem mudanca de turma
          @allocation = allocation
          allocations.each do |al|
            changed_status_to_accepted = ((al.status.to_i != Allocation_Activated.to_i) and (new_status.to_i == Allocation_Activated.to_i))
            al.update_attributes(:status => new_status)

            Notifier.enrollment_accepted(allocation.user.email, allocation.group.code_semester).deliver if changed_status_to_accepted
          end # allocations
        end # if
      end # transaction

      flash[:notice] = t(:enrollment_successful_update, :scope => [:allocations, :manage])
    rescue ActiveRecord::RecordNotUnique
      error     = true
      msg_error = t(:student_already_in_group, :scope => [:allocations, :error])
    rescue Exception
      error     = true
      msg_error = t(:enrollment_unsuccessful_update, :scope => [:allocations, :manage])
    end

    if error
      render :js => "javascript:flash_message('#{msg_error}', 'alert');"
    else
      respond_to do |format|
        format.html { render :action => :show }
        format.json { render :json => {:status => "ok"}  }
      end
    end
  end

  # DELETE /allocations/1/cancel
  # DELETE /allocations/1/cancel_request
  def destroy
    authorize! :cancel, Allocation if not params.include?(:type)
    authorize! :cancel_request, Allocation if params.include?(:type) and params[:type] == 'request'

    @allocation = Allocation.find(params[:id])

    begin
      error = false
      if params.include?(:type) and params[:type] == 'request' and @allocation.status == Allocation_Pending
        @allocation.destroy
        message = t(:enrollm_request_cancel_message)
      else
        @allocation.update_attributes!(:status => Allocation_Cancelled)
        message = t(:enrollm_cancelled_message)
      end
    rescue Exception => e
      message = t(:enrollm_not_cancelled_message)
      error   = true
    end

    respond_to do |format|
      unless error
        format.html { redirect_to(enrollments_url, notice: message) }
        format.json { head :ok }
      else
        format.html { redirect_to(enrollments_url, alert: message) }
        format.json { head :error }
      end
    end
  end

  def deactivate
    @allocation  = Allocation.find(params[:id])
    @text_search = params[:text_search]

    begin 
      authorize! :deactivate, @allocation
      raise "error" unless @allocation.update_attribute(:status, Allocation_Cancelled)

      render json: {success: true}
    rescue
      render json: {success: false, alert: t(:not_deactivated, scope: [:allocations, :error])}, status: :unprocessable_entity
    end
  end

  def activate
    @allocation       = Allocation.find(params[:id])
    allocation_tag_id = @allocation.allocation_tag_id

    begin
      authorize! :activate, @allocation
      raise "error" unless @allocation.update_attribute(:status, Allocation_Activated)

      render json: {success: true}
    rescue
      render json: {success: false, alert: t(:not_activated, scope: [:allocations, :error])}, status: :unprocessable_entity
    end
  end  

  def reactivate
    @allocation = Allocation.find(params[:id])
    offer = @allocation.offer || @allocation.group.offer
    ok = (offer.enrollment_start_date.to_date..(offer.enrollment_end_date.try(:to_date) || offer.end_date.to_date)).include?(Date.today)

    respond_to do |format|
      if (ok and @allocation.update_attribute(:status, Allocation_Pending_Reactivate))
        format.html { redirect_to(enrollments_url, notice: t(:enrollm_request, :scope => [:allocations, :success])) }        
        format.json { head :ok }
      else
        format.html { redirect_to(enrollments_url, alert: t(:enrollm_request, :scope => [:allocations, :error])) }        
        format.json { head :error }
      end
    end
  end  

  private

    def status_hash_of_allocation(allocation_status)
      case allocation_status
        when Allocation_Pending, Allocation_Pending_Reactivate
          status_hash.select { |k,v| [allocation_status, Allocation_Activated, Allocation_Rejected].include?(k) }
        when Allocation_Activated
          status_hash.select { |k,v| [allocation_status, Allocation_Cancelled].include?(k) }
        when Allocation_Cancelled, Allocation_Rejected
          status_hash.select { |k,v| [allocation_status, Allocation_Activated].include?(k) }
      end
    end

    def allocate(allocation_tags_ids, user_id, profile, status, id = nil)
      return false unless ((params.include?(:allocation_tags_ids) or params.include?(:allocation_tag_id)) and params.include?(:user_id) and (profile != ''))

      total, corrects = 0, 0
      unless params[:id].nil? # se alocação já existe (id não será nulo), então está desativada e deve ser reativada
        allocation        = Allocation.find(params[:id])
        allocation.status = Allocation_Pending_Reactivate
        total    = 1
        corrects = 1 if allocation.save
      else # se alocação está sendo realizada agora, deve ser criada
        total = [allocation_tags_ids].compact.flatten.size
        [allocation_tags_ids].compact.flatten.each do |id|
          allocation = Allocation.new({
            :user_id => params[:user_id],
            :allocation_tag_id => id,
            :profile_id => profile,
            :status => status
          })
          corrects = corrects + 1 if allocation.save
        end # allocation_tags_ids.each
      end # unless params[:id].nil?

      return (corrects == total)
    end

end
