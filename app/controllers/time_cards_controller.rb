class TimeCardsController < ApplicationController
  before_action :logged_in_user
  before_action :correct_but_superior_user, only: [:show]
  before_action :admin_user, only: [:new, :create]
  before_action :non_admin_user, only: [:show, :edit, :update]  
  
  def show
    
    @person = TimeCard::Person.new(name: 'bob', age: '18')
    
    @user = User.find(params[:id])
    if params[:year] && params[:month]
      @year = params[:year].to_i
      @month = params[:month].to_i
    elsif session[:month] && session[:year]
      @year = session[:year]
      @month = session[:month]
    else
      today = Time.current
      @year = today.year
      @month = today.month
    end
    
    @day = Time.current.day
    @time_cards = monthly_time_cards(@user, @year, @month)
    @time_card = TimeCard.today(@user)
    @first_day = Date.new(@year, @month, 1)
    @last_day = Date.new(@year, @month, 1).next_month.prev_day
    # @time_info = TimeInfo.all.last
    @time_cards_count = all_time_cards_for_count(@user)
    @user_time_cards = TimeCard.where(user: @user)
    store(@year,@month)
    
    #上長へ承認するボタン
    @superiors = User.where(superior: true)
    @superiors_list = superiors(@superiors)
    @monthly_authentication = authentication_index(@user, @year, @month)
    
    if @user.superior 
      #上長ユーザーのみ必要
      #一ヶ月認証
      @authentication_events = MonthlyAuthentication.where(certifier: @user.id).where("status like ?", "%申請中").order(:user_id)
      
      #残業申請認証
      @over_time_authentications = TimeCard.where(certifer: @user.id).order(:user_id)
      
      #勤怠変更認証
      @change_time_cards = TimeCard.where(change_certifier: @user.id).order(:user_id)
    end
    #CSV
    respond_to do |format|
      format.html {}
      format.csv do
       send_data render_to_string, filename: "#{@year}_#{@month}_kintai.csv", type: :csv
      end
    end
  end
  
  def up_overwork
    #byebug
    @user = User.find_by(id: params[:id])
    condition = { user: @user, year: params[:year], month: params[:month], day: params[:day] }
    TimeCard.find_by(condition) ? @time_card = TimeCard.find_by(condition) : @time_card = TimeCard.new(condition)
    
    if params[:check].to_i != 1
      time = Time.zone.local(params[:year], params[:month], params[:day], params[:time_hour], params[:time_minute], 0)
    else
      time = Time.zone.local(params[:year], params[:month], params[:day], params[:time_hour], params[:time_minute], 0).next_day
    end
    
    @time_card.over_work = time
    @time_card.content = params[:content]
    @time_card.certifer = params[:superior]
    @superior = User.find(params[:superior])
    @time_card.status = "#{@superior.name}に残業申請中"
    @time_card.save
    
    redirect_to time_card_path(@user)
    
  end
  
  def authenticate
    @authenticated_time_cards = TimeCard.where(certifer: current_user.id)
      @authenticated_time_cards.each do |obj|
        if params[obj.user.id.to_s][obj.year.to_s] && params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s] && params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s]
          if params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:check] == "1"
            if params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] == "承認" || params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] == "否認"
              if obj.status.include?("残業") && obj.status.include?("勤怠変更") 
                status_0 = obj.status.split(" ")[0]
                status_1 = obj.status.split(" ")[1]
                status_0 = "残業" + params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] + "済"
                obj.status = status_0 + " " + status_1
              elsif obj.status.include?("勤怠変更")
                obj.status = "残業" + params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] + "済 " + obj.status
              else
                obj.status = "残業" + params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] + "済"
              end
              obj.certifer = nil
              obj.save
            else
              obj.status = params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status]
              obj.certifer = nil
              obj.save
            end
          end
        end
      end
      redirect_to time_card_path(id: current_user.id)
  end
  
  def authenticate_2
    @authenticated_time_cards = TimeCard.where(change_certifier: current_user.id)
      @authenticated_time_cards.each do |obj|
        if params[obj.user.id.to_s][obj.year.to_s] && params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s] && params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s]
          if params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:check] == "1"
            if params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] == "承認" || params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] == "否認"
              if obj.status.include?("勤怠変更") && obj.status.include?("残業")
                status_0 = obj.status.split(" ")[0]
                status_1 = obj.status.split(" ")[1]
                status_1 = "勤怠変更" + params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] + "済"
                obj.status = status_0 + " " + statis_1
              elsif obj.status.include?("残業")
                obj.status = obj.status + " " + "勤怠変更" + params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] + "済"
              else
                obj.status = "勤怠変更" + params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] + "済"
              end
              if params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status] == "承認"
                obj.in_at = obj.tmp_in_at
                obj.out_at = obj.tmp_out_at
                obj.change_certifier = nil
                obj.save
              end
              obj.tmp_in_at = nil
              obj.tmp_out_at = nil
              obj.change_certifier = nil
              obj.save
            else
              obj.status = params[obj.user.id.to_s][obj.year.to_s][obj.month.to_s][obj.day.to_s][:status]
              obj.tmp_in_at = nil
              obj.tmp_out_at = nil
              obj.change_certifier = nil
              obj.save
            end
          end
        end
      end
      redirect_to time_card_path(id: current_user.id)
  end
  
  def updata
    @user = User.find(params[:id])
    @time_card = TimeCard.today(@user)
      if params[:in]
        @time_card.in_at = Time.now
      elsif params[:out]
        @time_card.out_at = Time.now
      end
      @time_card.save
      redirect_to time_card_path(@user)
  end
  
  def new
    @time_info = TimeInfo.new
  end
  
  def create
    
    # これは使えない @time_info = TimeInfo.new(must_work_time: params[:must_work_time], sd_work_time: params[:sd_work_time])
     @time_info = TimeInfo.new(time_info_params)
    if @time_info.save
      redirect_to current_user
    end

  end
  
  def edit
    # if request.get?
      @user = User.find(params[:id])
      @year = session[:year]
      @month = session[:month]
      @time_cards = monthly_time_cards(@user, @year, @month)
      
      #上長へ承認するボタン
      @superiors = User.where(superior: true)
      @superiors_list = superiors(@superiors)
    # else
      
    # end
  end
  
  def update
    #byebug
    
    @user = User.find(params[:id])
    @year = session[:year]
    @month = session[:month]
    number_of_days_in_month = Date.new(@year, @month, 1).next_month.prev_day.day
    # @time_cards = monthly_time_cards(@user, @year, @month)
    (1..number_of_days_in_month).each do |number|
    s = (number - 1).to_s

      condition = { user: @user, year: @year, month: @month, day: number }
      superior = User.find(params[:time_cards][s][:change_certifier])
      time_card = TimeCard.find_by(condition) ? TimeCard.find_by(condition) : TimeCard.new(condition)
      current_day = number
      out_day = params[:time_cards][s][:check] == "1" ? current_day + 1 : current_day 
    
          if !params[:time_cards][s]["tmp_out_at(4i)"].empty? && !params[:time_cards][s]["tmp_out_at(5i)"].empty?
            time_card.tmp_out_at = Time.zone.local(@year, @month, out_day, params[:time_cards][s]["tmp_out_at(4i)"], params[:time_cards][s]["tmp_out_at(5i)"], 0)
            if !params[:time_cards][s]["tmp_in_at(4i)"].empty? && !params[:time_cards][s]["tmp_in_at(5i)"].empty?
              time_card.tmp_in_at = Time.zone.local(@year, @month, current_day, params[:time_cards][s]["tmp_in_at(4i)"], params[:time_cards][s]["tmp_in_at(5i)"], 0)
              time_card.status = "#{superior.name}に勤怠変更申請中"
              time_card.remark = params[:time_cards][s][:remark] if !params[:time_cards][s][:remark].empty?
              time_card.change_certifier = params[:time_cards][s][:change_certifier]
              time_card.save
            else
              time_card.status = "#{superior.name}に勤怠変更申請中"
              time_card.remark = params[:time_cards][s][:remark] if !params[:time_cards][s][:remark].empty?
              time_card.change_certifier = params[:time_cards][s][:change_certifier]
              time_card.save
            end
          else
            if !params[:time_cards][s]["tmp_in_at(4i)"].empty? && !params[:time_cards][s]["tmp_in_at(5i)"].empty?
              time_card.tmp_in_at = Time.zone.local(@year, @month, current_day, params[:time_cards][s]["tmp_in_at(4i)"], params[:time_cards][s]["tmp_in_at(5i)"], 0)
              time_card.status = "#{superior.name}に勤怠変更申請中"
              time_card.remark = params[:time_cards][s][:remark] if !params[:time_cards][s][:remark].empty?
              time_card.change_certifier = params[:time_cards][s][:change_certifier]
              time_card.save
            else
            end
          end 
    end
    redirect_to @user

  end
  
  
  
  def add
    @user = User.find(params[:id])
    @year = session[:year]
    @month = session[:month] + 1
    if @month == 13
      @year = @year + 1
      @month = 1
    end
    store(@year,@month)
    redirect_to time_card_path(@user)
  end
  
  def subtract
    @user = User.find(params[:id])
    @year = session[:year]
    @month = session[:month] - 1
    if @month == 0
      @year = @year - 1
      @month = 12
    end
    store(@year,@month)
    redirect_to time_card_path(@user)
  end

  private
  
    def store(year,month)
      session[:year] = year
      session[:month] = month
    end
  
    def time_cards_params
      params.require(:time_cards).permit(:in_at, :out_at, :content)
                                  
    end

    # 指定年月の全ての日のタイムカードの配列を取得する（タイムカードが存在しない日はnil）
    def monthly_time_cards(user, year, month)
      number_of_days_in_month = Date.new(year, month, 1).next_month.prev_day.day
      results = Array.new(number_of_days_in_month) # 月の日数分nilで埋めた配列を用意
      time_cards = TimeCard.monthly(user, year, month)
      time_cards.each do |card|
        results[card.day - 1] = card
      end
      results
    end
    
    def all_time_cards_for_count(user)
      time_cards = TimeCard.where(user: user)
      count = 0
      time_cards.each do |card|
        if card.in_at && card.out_at
          count = count + 1
        end
      end
      count
    end
    
    # def time_info_params
    #   params.require(:time_info).permit(:must_work_time,:sd_work_time) 
    # end
    
    def admin_user
      redirect_to(root_url) unless current_user.admin?
    end
    
    def non_admin_user
      redirect_to(root_url) if current_user.admin?
    end
    
    def superiors(superiors)
      array = []
      superiors.each_with_index do |superior, index|
        array[index] = []
        array[index] << superior.name << superior.id
      end
      
      array
      
    end
    
    def authentication_index(user,year,month)
      index = user.monthly_authentications.find_by(year: year, month: month) 
      if index
        index
      else
        index2 = user.monthly_authentications.new(year: year, month: month)
        index2.save
        index2
      end 
    end
    

end
