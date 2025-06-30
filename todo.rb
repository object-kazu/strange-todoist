#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'date'

# TODO管理システム Ruby版
class TodoApp
  # カレンダー表示の区切り線
  CALENDAR_SEPARATOR = "----+----------+-------------+-----------------------+------------------------"

  def initialize
    @data_dir = Dir.home
    @todo_data_file = File.join(@data_dir, '.todo_data.csv')
    @calendar_data_file = File.join(@data_dir, '.todo_calendar.csv')
    @config_file = File.join(@data_dir, '.todo_config.csv')
    
    @projects = []
    @tasks = []
    @calendar_data = []
    @config = {}
    
    init_files
    load_data
  end

  def run
    puts "\e[36mTODO管理システムを起動しています...\e[0m"
    main_menu
  end

  private

  # ファイル初期化
  def init_files
    init_todo_data_file unless File.exist?(@todo_data_file)
    init_calendar_data_file unless File.exist?(@calendar_data_file)
    init_config_file unless File.exist?(@config_file)
  end

  def init_todo_data_file
    CSV.open(@todo_data_file, 'w') do |csv|
      csv << %w[id project_id project_name task_id task_name level priority repeat_type created_date completed_date parent_id]
    end
  end

  def init_calendar_data_file
    CSV.open(@calendar_data_file, 'w') do |csv|
      csv << %w[date month week weekday day completed_task project_name]
    end
  end

  def init_config_file
    CSV.open(@config_file, 'w') do |csv|
      csv << %w[key value]
      csv << ['sort_order', 'priority']
      csv << ['current_quarter', "#{Date.today.year}-Q#{((Date.today.month - 1) / 3) + 1}"]
    end
  end

  # データ読み込み
  def load_data
    load_todo_data
    load_calendar_data
    load_config_data
  end

  def load_todo_data
    return unless File.exist?(@todo_data_file)

    @projects.clear
    @tasks.clear

    CSV.foreach(@todo_data_file, headers: true) do |row|
      if row['task_id'] == '0'
        @projects << Project.new(
          id: row['id'].to_i,
          name: row['project_name'],
          priority: row['priority'],
          created_date: row['created_date']
        )
      else
        @tasks << Task.new(
          id: row['id'].to_i,
          project_id: row['project_id'].to_i,
          project_name: row['project_name'],
          task_id: row['task_id'].to_i,
          name: row['task_name'],
          level: row['level'].to_i,
          priority: row['priority'],
          repeat_type: row['repeat_type'] || 'none',
          created_date: row['created_date'],
          completed_date: row['completed_date'],
          parent_id: row['parent_id']&.to_i
        )
      end
    end
  end

  def load_calendar_data
    return unless File.exist?(@calendar_data_file)

    @calendar_data.clear
    CSV.foreach(@calendar_data_file, headers: true) do |row|
      @calendar_data << CalendarEntry.new(
        date: row['date'],
        month: row['month'],
        week: row['week'],
        weekday: row['weekday'],
        day: row['day'],
        completed_task: row['completed_task'],
        project_name: row['project_name']
      )
    end
  end

  def load_config_data
    return unless File.exist?(@config_file)

    @config.clear
    CSV.foreach(@config_file, headers: true) do |row|
      @config[row['key']] = row['value']
    end
  end

  # データ保存
  def save_data
    save_todo_data
    save_calendar_data
    save_config_data
  end

  def save_todo_data
    CSV.open(@todo_data_file, 'w') do |csv|
      csv << %w[id project_id project_name task_id task_name level priority repeat_type created_date completed_date parent_id]
      
      @projects.each do |project|
        csv << [
          project.id, project.id, project.name, 0, '',
          0, project.priority, 'none', project.created_date, '', ''
        ]
      end

      @tasks.each do |task|
        csv << [
          task.id, task.project_id, task.project_name, task.task_id, task.name,
          task.level, task.priority, task.repeat_type, task.created_date,
          task.completed_date, task.parent_id
        ]
      end
    end
  end

  def save_calendar_data
    CSV.open(@calendar_data_file, 'w') do |csv|
      csv << %w[date month week weekday day completed_task project_name]
      @calendar_data.each do |entry|
        csv << [
          entry.date, entry.month, entry.week, entry.weekday,
          entry.day, entry.completed_task, entry.project_name
        ]
      end
    end
  end

  def save_config_data
    CSV.open(@config_file, 'w') do |csv|
      csv << %w[key value]
      @config.each { |key, value| csv << [key, value] }
    end
  end

  # 次のIDを取得
  def next_id
    all_ids = (@projects.map(&:id) + @tasks.map(&:id))
    all_ids.empty? ? 1 : all_ids.max + 1
  end

  # メニューシステム
  def main_menu
    loop do
      puts "\n\e[32m=== TODO管理システム ===\e[0m"
      puts "t. TODOモード"
      puts "c. カレンダーモード"
      puts "q. 終了"
      print "モードを選択してください [t,c,q]: "

      choice = gets.chomp.downcase

      case choice
      when 't'
        todo_mode_menu
      when 'c'
        calendar_mode_menu
      when 'q'
        save_data
        puts "\e[32mありがとうございました\e[0m"
        exit
      else
        puts "\e[31m無効な選択です\e[0m"
      end
    end
  end

  def todo_mode_menu
    loop do
      puts "\n\e[34m=== TODOモード ===\e[0m"
      puts "p.  プロジェクト作成        t.  タスク作成"
      puts "pl. プロジェクト一覧表示     tl. タスク一覧表示"
      puts "                        f.  タスク完了"
      puts "pd. プロジェクト削除        td. タスク削除"
      puts "----------------------------------------------------"
      puts "rm. リネーム"
      puts "cp. プライオリティ変更"
      puts "cr. 繰り返し変更"
      puts "r.  戻る"
      puts "q.  終了"
      puts "----------------------------------------------------"
      print "選択してください [p,t,pl,tl,f,pd,td,rm,cp,cr,r,q]: "
      puts ""
      
      choice = gets.chomp.downcase

      case choice
      when 'p'
        create_project
      when 't'
        create_task
      when 'pl'
        display_projects
      when 'tl'
        display_tasks
      when 'f'
        complete_task
      when 'pd'
        delete_project
      when 'td'
        delete_task
      when 'rm'
        rename_item
      when 'cp'
        change_priority
      when 'cr'
        change_repeat
      when 'r'
        break
      when 'q'
        return_to_main_menu
      else
        puts "\e[31m無効な選択です\e[0m"
      end
    end
  end

  def calendar_mode_menu
    # 直接月選択画面に進む
    display_calendar
  end

  def return_to_main_menu
    save_data
    puts "\e[33mメインメニューに戻ります\e[0m"
    main_menu
  end

  # プロジェクト操作
  def create_project
    puts "\e[36m新しいプロジェクトを作成します\e[0m"
    print "プロジェクト名を入力してください (q=戻る): "
    
    name = gets.chomp
    return if name.downcase == 'q'
    
    if name.empty?
      puts "\e[31mプロジェクト名が入力されていません\e[0m"
      return
    end

    print "プライオリティを選択してください (h:高, m:中, l:低) [m]: "
    priority_input = gets.chomp.downcase
    
    priority = case priority_input
                when 'h' then 'high'
                when 'l' then 'low'
                else 'medium'
                end

    project = Project.new(
      id: next_id,
      name: name,
      priority: priority,
      created_date: Date.today.to_s
    )

    @projects << project
    puts "\e[32mプロジェクト「#{name}」を作成しました (ID: #{project.id})\e[0m"
  end

  def display_projects
    puts "\e[34m=== プロジェクト一覧 ===\e[0m"
    
    @projects.each_with_index do |project, index|
      color = priority_color(project.priority)
      puts "\e[#{color}m[#{index + 1}] #{project.name}\e[0m (優先度: #{project.priority})"
    end
  end

  # タスク操作
  def create_task
    puts "\e[36m新しいタスクを作成します\e[0m"
    
    display_tasks
    print "親となるプロジェクト/タスクのIDを入力してください (q=戻る): "
    
    input = gets.chomp
    return if input.downcase == 'q'
    
    parent_id = input.to_i
    
    # プロジェクトまたはタスクを検索
    parent_project = @projects.find { |p| p.id == parent_id }
    parent_task = @tasks.find { |t| t.id == parent_id && t.completed_date.nil? }
    
    if parent_project
      project = parent_project
      parent_task_id = nil
      level = 1
    elsif parent_task
      project = @projects.find { |p| p.id == parent_task.project_id }
      parent_task_id = parent_task.id
      level = parent_task.level + 1
    else
      puts "\e[31m指定されたIDが見つかりません\e[0m"
      return
    end
    
    print "タスク名を入力してください (q=戻る): "
    name = gets.chomp
    return if name.downcase == 'q'
    
    if name.empty?
      puts "\e[31mタスク名が入力されていません\e[0m"
      return
    end

    print "プライオリティを選択してください (h:高, m:中, l:低) [m]: "
    priority_input = gets.chomp.downcase
    
    priority = case priority_input
                when 'h' then 'high'
                when 'l' then 'low'
                else 'medium'
                end

    print "繰り返し設定 (n:なし, d:毎日, w:毎週, m:毎月) [n]: "
    repeat_input = gets.chomp.downcase
    
    repeat_type = case repeat_input
                  when 'd' then 'daily'
                  when 'w' then 'weekly'
                  when 'm' then 'monthly'
                  else 'none'
                  end

    # 既存タスクの最大task_idを取得
    if parent_task_id
      # サブタスクの場合は親タスクの子タスクから最大task_idを取得
      sibling_tasks = @tasks.select { |t| t.parent_id == parent_task_id }
      max_task_id = sibling_tasks.map(&:task_id).max || 0
    else
      # プロジェクト直下のタスクの場合
      project_tasks = @tasks.select { |t| t.project_id == project.id && t.parent_id.nil? }
      max_task_id = project_tasks.map(&:task_id).max || 0
    end

    task = Task.new(
      id: next_id,
      project_id: project.id,
      project_name: project.name,
      task_id: max_task_id + 1,
      name: name,
      level: level,
      priority: priority,
      repeat_type: repeat_type,
      created_date: Date.today.to_s,
      completed_date: nil,
      parent_id: parent_task_id
    )

    @tasks << task
    puts "\e[32mタスク「#{name}」を作成しました (ID: #{task.id})\e[0m"
  end

  def display_tasks
    puts "\e[34m=== タスク一覧 ===\e[0m"
    
    @projects.each_with_index do |project, project_index|
      color = priority_color(project.priority)
      puts "\n\e[#{color}m[#{project_index + 1}] (id:#{project.id})   #{project.name}\e[0m"
      
      # プロジェクト直下のタスクを表示
      project_tasks = @tasks.select { |t| t.project_id == project.id && t.completed_date.nil? && t.parent_id.nil? }
      project_tasks.each do |task|
        display_task_with_children(task, project_index + 1, "  ")
      end
    end
  end

  def display_task_with_children(task, project_number, indent)
    task_color = priority_color(task.priority)
    puts "#{indent}\e[#{task_color}m[#{project_number}.#{task.task_id}] (id:#{task.id})   #{task.name}\e[0m"
    
    # 子タスクを表示
    child_tasks = @tasks.select { |t| t.parent_id == task.id && t.completed_date.nil? }
    child_tasks.each do |child_task|
      display_task_with_children(child_task, project_number, indent + "  ")
    end
  end

  def complete_task
    puts "\e[36mタスクを完了します\e[0m"
    
    display_tasks
    print "完了するタスクのIDを入力してください (q=戻る): "
    
    input = gets.chomp
    return if input.downcase == 'q'
    
    task_id = input.to_i
    task = @tasks.find { |t| t.id == task_id && t.completed_date.nil? }
    
    unless task
      puts "\e[31m指定されたタスクが見つかりません\e[0m"
      return
    end

    task.completed_date = Date.today.to_s
    
    # カレンダーデータに追加
    today = Date.today
    weekday = today.strftime('%A')
    week_category = get_week_category(weekday)
    
    calendar_entry = CalendarEntry.new(
      date: today.to_s,
      month: today.month.to_s.rjust(2, '0'),
      week: week_category,
      weekday: weekday,
      day: today.day.to_s,
      completed_task: task.name,
      project_name: task.project_name
    )
    
    @calendar_data << calendar_entry
    
    puts "\e[32mタスク「#{task.name}」を完了しました\e[0m"
  end

  def delete_project
    puts "\e[36mプロジェクトを削除します\e[0m"
    
    display_projects
    print "削除するプロジェクトのIDを入力してください (q=戻る): "
    
    input = gets.chomp
    return if input.downcase == 'q'
    
    project_id = input.to_i
    project = @projects.find { |p| p.id == project_id }
    
    unless project
      puts "\e[31m指定されたプロジェクトが見つかりません\e[0m"
      return
    end

    # プロジェクトに関連するタスクがあるか確認
    related_tasks = @tasks.select { |t| t.project_id == project_id }
    
    if !related_tasks.empty?
      puts "\e[33m警告: このプロジェクトには#{related_tasks.length}個のタスクが含まれています\e[0m"
      print "本当に削除しますか？ (y/N): "
      confirm = gets.chomp.downcase
      
      unless confirm == 'y' || confirm == 'yes'
        puts "\e[33m削除をキャンセルしました\e[0m"
        return
      end
      
      # 関連するタスクも削除
      @tasks.reject! { |t| t.project_id == project_id }
      # カレンダーデータからも削除
      @calendar_data.reject! { |c| c.project_name == project.name }
    end

    # プロジェクトを削除
    @projects.reject! { |p| p.id == project_id }
    puts "\e[32mプロジェクト「#{project.name}」を削除しました\e[0m"
  end

  def delete_task
    puts "\e[36mタスクを削除します\e[0m"
    
    display_tasks
    print "削除するタスクのIDを入力してください (q=戻る): "
    
    input = gets.chomp
    return if input.downcase == 'q'
    
    task_id = input.to_i
    task = @tasks.find { |t| t.id == task_id }
    
    unless task
      puts "\e[31m指定されたタスクが見つかりません\e[0m"
      return
    end

    # 子タスクがあるか確認
    child_tasks = @tasks.select { |t| t.parent_id == task_id }
    
    if !child_tasks.empty?
      puts "\e[33m警告: このタスクには#{child_tasks.length}個の子タスクが含まれています\e[0m"
      print "本当に削除しますか？ (y/N): "
      confirm = gets.chomp.downcase
      
      unless confirm == 'y' || confirm == 'yes'
        puts "\e[33m削除をキャンセルしました\e[0m"
        return
      end
      
      # 子タスクも再帰的に削除
      delete_task_recursively(task_id)
    else
      # タスクを削除
      @tasks.reject! { |t| t.id == task_id }
      # カレンダーデータからも削除
      @calendar_data.reject! { |c| c.completed_task == task.name }
    end

    puts "\e[32mタスク「#{task.name}」を削除しました\e[0m"
  end

  def delete_task_recursively(task_id)
    # 子タスクを再帰的に削除
    child_tasks = @tasks.select { |t| t.parent_id == task_id }
    child_tasks.each do |child_task|
      delete_task_recursively(child_task.id)
    end
    
    # 該当タスクを削除
    task = @tasks.find { |t| t.id == task_id }
    @tasks.reject! { |t| t.id == task_id }
    # カレンダーデータからも削除
    @calendar_data.reject! { |c| c.completed_task == task.name } if task
  end

  def rename_item
    puts "\e[36mプロジェクト/タスクをリネームします\e[0m"
    
    display_tasks
    print "リネームするプロジェクト/タスクのIDを入力してください (q=戻る): "
    
    input = gets.chomp
    return if input.downcase == 'q'
    
    item_id = input.to_i
    
    # プロジェクトまたはタスクを検索
    project = @projects.find { |p| p.id == item_id }
    task = @tasks.find { |t| t.id == item_id }
    
    if project
      rename_project(project)
    elsif task
      rename_task(task)
    else
      puts "\e[31m指定されたIDが見つかりません\e[0m"
    end
  end

  def rename_project(project)
    puts "\e[36mプロジェクト「#{project.name}」をリネームします\e[0m"
    print "新しいプロジェクト名を入力してください (q=キャンセル): "
    
    new_name = gets.chomp
    return if new_name.downcase == 'q'
    
    if new_name.empty?
      puts "\e[31mプロジェクト名が入力されていません\e[0m"
      return
    end

    old_name = project.name
    project.name = new_name
    
    # 関連するタスクのproject_nameも更新
    @tasks.each do |task|
      if task.project_id == project.id
        task.project_name = new_name
      end
    end
    
    # カレンダーデータのproject_nameも更新
    @calendar_data.each do |entry|
      if entry.project_name == old_name
        entry.project_name = new_name
      end
    end
    
    puts "\e[32mプロジェクト「#{old_name}」を「#{new_name}」にリネームしました\e[0m"
  end

  def rename_task(task)
    puts "\e[36mタスク「#{task.name}」をリネームします\e[0m"
    print "新しいタスク名を入力してください (q=キャンセル): "
    
    new_name = gets.chomp
    return if new_name.downcase == 'q'
    
    if new_name.empty?
      puts "\e[31mタスク名が入力されていません\e[0m"
      return
    end

    old_name = task.name
    task.name = new_name
    
    # カレンダーデータのcompleted_taskも更新
    @calendar_data.each do |entry|
      if entry.completed_task == old_name
        entry.completed_task = new_name
      end
    end
    
    puts "\e[32mタスク「#{old_name}」を「#{new_name}」にリネームしました\e[0m"
  end

  def change_priority
    puts "\e[36mプライオリティを変更します\e[0m"
    
    display_tasks
    print "変更するタスク/プロジェクトのIDを入力してください (q=戻る): "
    
    input = gets.chomp
    return if input.downcase == 'q'
    
    id = input.to_i
    item = @projects.find { |p| p.id == id } || @tasks.find { |t| t.id == id }
    
    unless item
      puts "\e[31m指定されたIDが見つかりません\e[0m"
      return
    end

    print "新しいプライオリティを選択してください (h:高, m:中, l:低): "
    priority_input = gets.chomp.downcase
    
    new_priority = case priority_input
                   when 'h' then 'high'
                   when 'm' then 'medium'
                   when 'l' then 'low'
                   else
                     puts "\e[31m無効な選択です\e[0m"
                     return
                   end

    item.priority = new_priority
    item_type = item.is_a?(Project) ? 'プロジェクト' : 'タスク'
    puts "\e[32m#{item_type}「#{item.name}」のプライオリティを#{new_priority}に変更しました\e[0m"
  end

  def change_repeat
    puts "\e[36m繰り返し設定を変更します\e[0m"
    
    display_tasks
    print "変更するタスクのIDを入力してください (q=戻る): "
    
    input = gets.chomp
    return if input.downcase == 'q'
    
    task_id = input.to_i
    task = @tasks.find { |t| t.id == task_id }
    
    unless task
      puts "\e[31m指定されたタスクが見つかりません\e[0m"
      return
    end

    print "繰り返し設定 (n:なし, d:毎日, w:毎週, m:毎月): "
    repeat_input = gets.chomp.downcase
    
    new_repeat = case repeat_input
                 when 'n' then 'none'
                 when 'd' then 'daily'
                 when 'w' then 'weekly'
                 when 'm' then 'monthly'
                 else
                   puts "\e[31m無効な選択です\e[0m"
                   return
                 end

    task.repeat_type = new_repeat
    puts "\e[32mタスク「#{task.name}」の繰り返し設定を#{new_repeat}に変更しました\e[0m"
  end

  # カレンダー表示
  def display_calendar
    loop do
      puts "\e[34m=== カレンダー (完了履歴) ===\e[0m"
      
      print "表示する月を選択してください (1:今月, 2:先月, 3:指定月, r:戻る, q:終了) [1]: "
      choice = gets.chomp.downcase
      
      case choice
      when '', '1'
        display_monthly_calendar(Date.today)
      when '2'
        display_monthly_calendar(Date.today.prev_month)
      when '3'
        print "年を入力してください (YYYY): "
        year_input = gets.chomp
        return if year_input.downcase == 'q'
        
        print "月を入力してください (MM): "
        month_input = gets.chomp
        return if month_input.downcase == 'q'
        
        year = year_input.to_i
        month = month_input.to_i
        
        if year > 0 && month >= 1 && month <= 12
          display_monthly_calendar(Date.new(year, month, 1))
        else
          puts "\e[31m無効な日付です\e[0m"
        end
      when 'r'
        break
      when 'q'
        return_to_main_menu
      else
        puts "\e[31m無効な選択です\e[0m"
      end
    end
  end

  def display_monthly_calendar(target_date)
    year = target_date.year
    month = target_date.month
    days_in_month = Date.new(year, month, -1).day

    puts "\n\e[33m#{year}年#{month}月の完了履歴（全日表示）\e[0m"
    puts "\e[36m週数| 週区分   | 日付        | 完了タスク            | プロジェクト           \e[0m"
    puts CALENDAR_SEPARATOR

    # 完了データを日付ごとにグループ化
    month_str = month.to_s.rjust(2, '0')
    month_data = @calendar_data.select { |entry| entry.date.start_with?("#{year}-#{month_str}") }
    
    completed_by_date = {}
    month_data.each do |entry|
      date = entry.date
      completed_by_date[date] ||= []
      completed_by_date[date] << [entry.completed_task, entry.project_name]
    end

    # 週ごとにグループ化して表示
    current_week = nil
    week_days = []
    week_counter = 0

    (1..days_in_month).each do |day|
      date = Date.new(year, month, day)
      weekday = date.strftime('%A')
      week_category = get_week_category(weekday)

      if week_category != current_week
        display_week_group(week_counter, current_week, week_days, completed_by_date) if current_week && !week_days.empty?
        current_week = week_category
        week_days = []
        week_counter += 1
      end

      week_days << [date.to_s, day, weekday]
    end

    # 最後の週を表示
    display_week_group(week_counter, current_week, week_days, completed_by_date) if current_week && !week_days.empty?
  end

  def display_week_group(week_num, week_name, week_days, completed_by_date)
    # カラム幅の定義
    week_width = 4
    category_width = 9
    date_width = 12
    task_width = 22
    project_width = 22

    day_list = week_days.map { |_, day, _| day }.join(', ')
    
    # 完了タスクをペアで収集
    completed_pairs = []
    week_days.each do |date, _, _|
      if completed_by_date[date]
        completed_by_date[date].each do |task, project|
          completed_pairs << [task, project]
        end
      end
    end

    # タスクがない場合
    if completed_pairs.empty?
      completed_pairs = [['-', '-']]
    end

    # 各ペアを複数行で表示
    completed_pairs.each_with_index do |(task, project), index|
      if index == 0
        # 最初の行は週数、週区分、日付も表示
        week_str = format_field(week_num.to_s, week_width)
        category_str = format_field(week_name, category_width)
        date_str = format_field(day_list, date_width)
      else
        # 2行目以降は空白
        week_str = format_field('', week_width)
        category_str = format_field('', category_width)
        date_str = format_field('', date_width)
      end

      task_str = format_field(task, task_width)
      project_str = format_field(project, project_width)

      puts "#{week_str}| #{category_str}| #{date_str}| #{task_str}| #{project_str}"
    end

    puts CALENDAR_SEPARATOR
  end

  # 文字列を指定幅にフォーマット（日本語対応）
  def format_field(text, width)
    # 日本語文字の幅を考慮した表示幅計算
    display_width = text.each_char.sum { |char| char.bytesize == 1 ? 1 : 2 }
    
    if display_width > width
      # 文字列が長すぎる場合は切り詰め
      truncated = ''
      current_width = 0
      text.each_char do |char|
        char_width = char.bytesize == 1 ? 1 : 2
        break if current_width + char_width > width - 3 # "..."用に3文字残す
        truncated += char
        current_width += char_width
      end
      truncated += '...' if current_width < display_width
      text = truncated
      display_width = current_width + 3
    end

    # 右側にスペースを追加してパディング
    padding = width - display_width
    text + (' ' * padding)
  end

  # ユーティリティメソッド
  def get_week_category(weekday)
    case weekday
    when 'Saturday', 'Sunday', 'Monday'
      '土日月'
    when 'Tuesday', 'Wednesday'
      '火水'
    when 'Thursday', 'Friday'
      '木金'
    else
      '不明'
    end
  end

  def priority_color(priority)
    case priority
    when 'high'
      '31' # 赤
    when 'medium'
      '33' # 黄
    when 'low'
      '32' # 緑
    else
      '37' # 白
    end
  end
end

# データクラス
class Project
  attr_accessor :id, :name, :priority, :created_date

  def initialize(id:, name:, priority:, created_date:)
    @id = id
    @name = name
    @priority = priority
    @created_date = created_date
  end
end

class Task
  attr_accessor :id, :project_id, :project_name, :task_id, :name, :level, :priority, :repeat_type, :created_date, :completed_date, :parent_id

  def initialize(id:, project_id:, project_name:, task_id:, name:, level:, priority:, repeat_type:, created_date:, completed_date:, parent_id:)
    @id = id
    @project_id = project_id
    @project_name = project_name
    @task_id = task_id
    @name = name
    @level = level
    @priority = priority
    @repeat_type = repeat_type
    @created_date = created_date
    @completed_date = completed_date
    @parent_id = parent_id
  end
end

class CalendarEntry
  attr_accessor :date, :month, :week, :weekday, :day, :completed_task, :project_name

  def initialize(date:, month:, week:, weekday:, day:, completed_task:, project_name:)
    @date = date
    @month = month
    @week = week
    @weekday = weekday
    @day = day
    @completed_task = completed_task
    @project_name = project_name
  end
end

# メイン実行部
if __FILE__ == $0
  app = TodoApp.new
  app.run
end