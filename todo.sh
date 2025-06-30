#!/bin/zsh

# TODO管理シェルスクリプト
# macOS/zsh環境対応

# グローバル変数
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$HOME"
TODO_DATA_FILE="$DATA_DIR/.todo_data.csv"
CALENDAR_DATA_FILE="$DATA_DIR/.todo_calendar.csv"
CONFIG_FILE="$DATA_DIR/.todo_config.csv"

# 色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# ファイル初期化
init_files() {
    # メインデータファイル
    if [[ ! -f "$TODO_DATA_FILE" ]]; then
        echo "id,project_id,project_name,task_id,task_name,level,priority,created_date,completed_date,parent_id" > "$TODO_DATA_FILE"
    fi
    
    # カレンダーデータファイル
    if [[ ! -f "$CALENDAR_DATA_FILE" ]]; then
        echo "date,month,week,weekday,day,completed_task,project_name" > "$CALENDAR_DATA_FILE"
    fi
    
    # 設定ファイル
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "key,value" > "$CONFIG_FILE"
        echo "sort_order,priority" >> "$CONFIG_FILE"
        echo "current_quarter,$(date +%Y)-Q$(($(date +%-m-1)/3+1))" >> "$CONFIG_FILE"
    fi
}

# CSV読み込み関数
read_csv() {
    local file="$1"
    local delimiter="${2:-,}"
    
    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo "Error: File $file not found" >&2
        return 1
    fi
}

# CSV書き込み関数
write_csv() {
    local file="$1"
    local data="$2"
    
    echo "$data" >> "$file"
}

# 次のIDを取得
get_next_id() {
    local file="$1"
    local max_id=0
    
    if [[ -f "$file" ]]; then
        while IFS=',' read -r id rest; do
            if [[ "$id" =~ ^[0-9]+$ ]] && [[ $id -gt $max_id ]]; then
                max_id=$id
            fi
        done < <(tail -n +2 "$file")
    fi
    
    echo $((max_id + 1))
}

# プロジェクト作成
create_project() {
    echo -e "${CYAN}新しいプロジェクトを作成します${NC}"
    echo -n "プロジェクト名を入力してください: "
    read project_name
    
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}プロジェクト名が入力されていません${NC}"
        return 1
    fi
    
    echo -n "プライオリティを選択してください (1:高, 2:中, 3:低) [2]: "
    read priority_input
    
    case "$priority_input" in
        1) priority="high" ;;
        3) priority="low" ;;
        *) priority="medium" ;;
    esac
    
    local id=$(get_next_id "$TODO_DATA_FILE")
    local project_id=$id
    local created_date=$(date +%Y-%m-%d)
    
    local data="$id,$project_id,$project_name,0,,0,$priority,$created_date,"
    write_csv "$TODO_DATA_FILE" "$data"
    
    echo -e "${GREEN}プロジェクト「$project_name」を作成しました (ID: $id)${NC}"
}

# タスク作成
create_task() {
    echo -e "${CYAN}新しいタスクを作成します${NC}"
    
    # プロジェクト一覧表示
    echo -e "${YELLOW}利用可能なプロジェクト:${NC}"
    display_projects
    
    echo -n "プロジェクトIDを入力してください: "
    read project_id
    
    if [[ ! "$project_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}無効なプロジェクトIDです${NC}"
        return 1
    fi
    
    # プロジェクトの存在確認
    local project_exists=false
    local project_name=""
    
    while IFS=',' read -r id pid pname rest; do
        if [[ "$id" == "$project_id" ]]; then
            project_exists=true
            project_name="$pname"
            break
        fi
    done < <(tail -n +2 "$TODO_DATA_FILE")
    
    if [[ "$project_exists" == false ]]; then
        echo -e "${RED}指定されたプロジェクトが見つかりません${NC}"
        return 1
    fi
    
    echo -n "タスク名を入力してください: "
    read task_name
    
    if [[ -z "$task_name" ]]; then
        echo -e "${RED}タスク名が入力されていません${NC}"
        return 1
    fi
    
    echo -n "プライオリティを選択してください (1:高, 2:中, 3:低) [2]: "
    read priority_input
    
    case "$priority_input" in
        1) priority="high" ;;
        3) priority="low" ;;
        *) priority="medium" ;;
    esac
    
    local id=$(get_next_id "$TODO_DATA_FILE")
    local task_id=1
    local created_date=$(date +%Y-%m-%d)
    
    # 同じプロジェクト内のタスクIDを取得
    while IFS=',' read -r tid tpid tpname ttid rest; do
        if [[ "$tpid" == "$project_id" ]] && [[ "$ttid" =~ ^[0-9]+$ ]] && [[ $ttid -ge $task_id ]]; then
            task_id=$((ttid + 1))
        fi
    done < <(tail -n +2 "$TODO_DATA_FILE")
    
    local data="$id,$project_id,$project_name,$task_id,$task_name,1,$priority,$created_date,"
    write_csv "$TODO_DATA_FILE" "$data"
    
    echo -e "${GREEN}タスク「$task_name」を作成しました (ID: $id)${NC}"
}

# プロジェクト表示
display_projects() {
    echo -e "${BLUE}=== プロジェクト一覧 ===${NC}"
    
    local project_counter=0
    
    while IFS=',' read -r id project_id project_name task_id task_name level priority created_date completed_date parent_id; do
        if [[ "$task_id" == "0" ]]; then
            ((project_counter++))
            local priority_color=""
            case "$priority" in
                "high") priority_color="$RED" ;;
                "medium") priority_color="$YELLOW" ;;
                "low") priority_color="$GREEN" ;;
            esac
            
            echo -e "${priority_color}[$project_counter] $project_name ${NC}(優先度: $priority)"
        fi
    done < <(tail -n +2 "$TODO_DATA_FILE")
}

# タスク表示
display_tasks() {
    echo -e "${BLUE}=== タスク一覧 ===${NC}"
    
    local current_project=""
    local current_project_id=""
    local project_counter=0
    
    while IFS=',' read -r id project_id project_name task_id task_name level priority created_date completed_date parent_id; do
        if [[ "$task_id" == "0" ]]; then
            ((project_counter++))
            current_project="$project_name"
            current_project_id="$id"
            
            local priority_color=""
            case "$priority" in
                "high") priority_color="$RED" ;;
                "medium") priority_color="$YELLOW" ;;
                "low") priority_color="$GREEN" ;;
            esac
            
            echo -e "\n${priority_color}[$project_counter] $project_name${NC} (ID: $id)"
        elif [[ "$project_id" == "$current_project_id" ]] && [[ "$task_id" != "0" ]]; then
            local priority_color=""
            case "$priority" in
                "high") priority_color="$RED" ;;
                "medium") priority_color="$YELLOW" ;;
                "low") priority_color="$GREEN" ;;
            esac
            
            local indent="  "
            for ((i=1; i<level; i++)); do
                indent="$indent  "
            done
            
            echo -e "${indent}${priority_color}[$project_counter.$task_id] $task_name${NC} (ID: $id, 優先度: $priority)"
        fi
    done < <(tail -n +2 "$TODO_DATA_FILE")
}

# タスク完了
complete_task() {
    echo -e "${CYAN}タスクを完了します${NC}"
    
    display_tasks
    
    echo -n "完了するタスクのIDを入力してください (exit = q): "
    read task_id
    
    if [[ "$task_id" == "q" || "$task_id" == "Q" ]]; then
        echo -e "${YELLOW}タスク完了をキャンセルしました${NC}"
        return 0
    fi
    
    if [[ ! "$task_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}無効なタスクIDです。数値のみ入力してください${NC}"
        return 1
    fi
    
    local temp_file=$(mktemp)
    local found=false
    local completed_date=$(date +%Y-%m-%d)
    local task_name=""
    local project_name=""
    
    while IFS=',' read -r id project_id pname tid tname level priority task_status created_date comp_date parent_id; do
        if [[ "$id" == "$task_id" ]] && [[ "$tid" != "0" ]]; then
            found=true
            task_name="$tname"
            project_name="$pname"
            echo "$id,$project_id,$pname,$tid,$tname,$level,$priority,$created_date,$completed_date,$parent_id" >> "$temp_file"
            
            # カレンダーデータに追加
            local month=$(date +%m)
            local weekday=$(date +%A)
            local day=$(date +%d)
            local week_num=$(get_week_category "$weekday")
            
            local calendar_data="$completed_date,$month,$week_num,$weekday,$day,$tname,$project_name"
            write_csv "$CALENDAR_DATA_FILE" "$calendar_data"
        else
            echo "$id,$project_id,$pname,$tid,$tname,$level,$priority,$created_date,$comp_date,$parent_id" >> "$temp_file"
        fi
    done < <(tail -n +2 "$TODO_DATA_FILE")
    
    if [[ "$found" == true ]]; then
        head -n 1 "$TODO_DATA_FILE" > "$temp_file.new"
        cat "$temp_file" >> "$temp_file.new"
        mv "$temp_file.new" "$TODO_DATA_FILE"
        echo -e "${GREEN}タスク「$task_name」を完了しました${NC}"
    else
        echo -e "${RED}指定されたタスクが見つかりません${NC}"
    fi
    
    rm -f "$temp_file"
}

# プライオリティ変更
change_priority() {
    echo -e "${CYAN}プライオリティを変更します${NC}"
    
    display_tasks
    
    echo -n "変更するタスク/プロジェクトのIDを入力してください (exit = q): "
    read target_id
    
    if [[ "$target_id" == "q" || "$target_id" == "Q" ]]; then
        echo -e "${YELLOW}プライオリティ変更をキャンセルしました${NC}"
        return 0
    fi
    
    if [[ ! "$target_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}無効なIDです。数値のみ入力してください${NC}"
        return 1
    fi
    
    echo -n "新しいプライオリティを選択してください (1:高, 2:中, 3:低): "
    read priority_input
    
    case "$priority_input" in
        1) new_priority="high" ;;
        2) new_priority="medium" ;;
        3) new_priority="low" ;;
        *) 
            echo -e "${RED}無効な選択です${NC}"
            return 1
            ;;
    esac
    
    local temp_file=$(mktemp)
    local found=false
    local item_name=""
    
    while IFS=',' read -r id project_id project_name task_id task_name level priority created_date completed_date parent_id; do
        if [[ "$id" == "$target_id" ]]; then
            found=true
            if [[ "$task_id" == "0" ]]; then
                item_name="プロジェクト「$project_name」"
            else
                item_name="タスク「$task_name」"
            fi
            echo "$id,$project_id,$project_name,$task_id,$task_name,$level,$new_priority,$created_date,$completed_date,$parent_id" >> "$temp_file"
        else
            echo "$id,$project_id,$project_name,$task_id,$task_name,$level,$priority,$created_date,$completed_date,$parent_id" >> "$temp_file"
        fi
    done < <(tail -n +2 "$TODO_DATA_FILE")
    
    if [[ "$found" == true ]]; then
        head -n 1 "$TODO_DATA_FILE" > "$temp_file.new"
        cat "$temp_file" >> "$temp_file.new"
        mv "$temp_file.new" "$TODO_DATA_FILE"
        echo -e "${GREEN}${item_name}のプライオリティを${new_priority}に変更しました${NC}"
    else
        echo -e "${RED}指定されたIDが見つかりません${NC}"
    fi
    
    rm -f "$temp_file"
}

# 週カテゴリ取得
get_week_category() {
    local weekday="$1"
    
    case "$weekday" in
        "Saturday"|"Sunday"|"Monday") echo "土日月" ;;
        "Tuesday"|"Wednesday") echo "火水" ;;
        "Thursday"|"Friday") echo "木金" ;;
        *) echo "不明" ;;
    esac
}

# カレンダー表示
display_calendar() {
    echo -e "${BLUE}=== カレンダー (完了履歴) ===${NC}"
    
    echo -n "表示する月を選択してください (1:今月, 2:先月, 3:指定月) [1]: "
    read month_choice
    
    local target_month=""
    local target_year=""
    
    case "$month_choice" in
        2)
            target_month=$(date -d "last month" +%m 2>/dev/null || date -v-1m +%m)
            target_year=$(date -d "last month" +%Y 2>/dev/null || date -v-1m +%Y)
            ;;
        3)
            echo -n "年を入力してください (YYYY): "
            read input_year
            echo -n "月を入力してください (MM): "
            read input_month
            target_year="$input_year"
            target_month="$input_month"
            ;;
        *)
            target_month=$(date +%m)
            target_year=$(date +%Y)
            ;;
    esac
    
    # 月の日数を取得（macOS対応）
    local days_in_month
    case "$target_month" in
        "01"|"03"|"05"|"07"|"08"|"10"|"12") days_in_month=31 ;;
        "04"|"06"|"09"|"11") days_in_month=30 ;;
        "02")
            # うるう年判定
            if (( target_year % 4 == 0 && (target_year % 100 != 0 || target_year % 400 == 0) )); then
                days_in_month=29
            else
                days_in_month=28
            fi
            ;;
        *) days_in_month=31 ;;
    esac
    
    echo -e "\n${YELLOW}$target_year年$target_month月の完了履歴（全日表示）${NC}"
    echo -e "${CYAN}週区分 | 日付        | 曜日     | 完了タスク | プロジェクト${NC}"
    echo "--------------------------------------------------------"
    
    # デバッグ: 月の日数を表示
    # echo "Debug: days_in_month = $days_in_month"
    
    # 完了データを連想配列に格納
    typeset -A completed_tasks
    while IFS=',' read -r date month week weekday day completed_task project_name; do
        if [[ "$date" =~ ^$target_year-$target_month ]]; then
            completed_tasks["$date"]="$week|$weekday|$completed_task|$project_name"
        fi
    done < <(tail -n +2 "$CALENDAR_DATA_FILE")
    
    # 週区分ごとにグループ化して表示
    local current_week=""
    local week_days=()
    local week_counter=0
    
    for ((day=1; day<=days_in_month; day++)); do
        local formatted_day
        printf -v formatted_day "%02d" "$day"
        local current_date="$target_year-$target_month-$formatted_day"
        
        # 曜日を取得（macOS対応）
        local weekday
        weekday=$(date -j -f "%Y-%m-%d" "$current_date" +%A 2>/dev/null || date -d "$current_date" +%A 2>/dev/null || echo "Unknown")
        
        local week_category=$(get_week_category "$weekday")
        
        # 週区分が変わったら前の週を表示
        if [[ "$week_category" != "$current_week" ]]; then
            # 前の週がある場合は表示
            if [[ -n "$current_week" && ${#week_days[@]} -gt 0 ]]; then
                display_week_group "$week_counter" "$current_week" "${week_days[@]}"
            fi
            current_week="$week_category"
            week_days=()
            ((week_counter++))
        fi
        
        week_days+=("$current_date|$day|$weekday")
    done
    
    # 最後の週を表示
    if [[ -n "$current_week" && ${#week_days[@]} -gt 0 ]]; then
        display_week_group "$week_counter" "$current_week" "${week_days[@]}"
    fi
}

# 週グループ表示
display_week_group() {
    local week_num="$1"
    local week_name="$2"
    shift 2
    
    local day_list=""
    local completed_task=""
    local project_name=""
    local has_completed=false
    
    # 日付リストを作成し、完了タスクがあるかチェック
    while [[ $# -gt 0 ]]; do
        local day_info="$1"
        shift
        
        IFS='|' read -r date day_num weekday <<< "$day_info"
        
        if [[ -n "$day_list" ]]; then
            day_list="$day_list, $day_num"
        else
            day_list="$day_num"
        fi
        
        # 完了タスクがあるかチェック（グローバル変数参照）
        if [[ -n "${completed_tasks[$date]}" ]]; then
            IFS='|' read -r week weekday_stored task project <<< "${completed_tasks[$date]}"
            if [[ "$has_completed" == false ]]; then
                completed_task="$task"
                project_name="$project"
                has_completed=true
            else
                completed_task="$completed_task, $task"
                project_name="$project_name, $project"
            fi
        fi
    done
    
    if [[ "$has_completed" == false ]]; then
        completed_task="-"
        project_name="-"
    fi
    
    printf "%-6s | %-11s | %-8s | %-10s | %s\n" "$week_num" "$day_list" "$week_name" "$completed_task" "$project_name"
    echo "--------------------------------------------------------"
}

# TODOモードメニュー
todo_mode_menu() {
    while true; do
        echo -e "\n${BLUE}=== TODOモード ===${NC}"
        echo "1. プロジェクト作成"
        echo "2. タスク作成"
        echo "3. プロジェクト一覧表示"
        echo "4. タスク一覧表示"
        echo "5. タスク完了"
        echo "6. プライオリティ変更"
        echo "r. 戻る"
        echo "q. 終了"
        echo -n "選択してください [1-6,r,q]: "
        
        read choice
        
        case "$choice" in
            1) create_project ;;
            2) create_task ;;
            3) display_projects ;;
            4) display_tasks ;;
            5) complete_task ;;
            6) change_priority ;;
            "r"|"R") break ;;
            "q"|"Q") 
                echo -e "${GREEN}ありがとうございました${NC}"
                exit 0
                ;;
            *) echo -e "${RED}無効な選択です${NC}" ;;
        esac
    done
}

# カレンダーモードメニュー
calendar_mode_menu() {
    while true; do
        echo -e "\n${BLUE}=== カレンダーモード ===${NC}"
        echo "1. 完了履歴表示"
        echo "r. 戻る"
        echo "q. 終了"
        echo -n "選択してください [1,r,q]: "
        
        read choice
        
        case "$choice" in
            1) display_calendar ;;
            "r"|"R") break ;;
            "q"|"Q") 
                echo -e "${GREEN}ありがとうございました${NC}"
                exit 0
                ;;
            *) echo -e "${RED}無効な選択です${NC}" ;;
        esac
    done
}

# メインメニュー
main_menu() {
    while true; do
        echo -e "\n${GREEN}=== TODO管理システム ===${NC}"
        echo "1. TODOモード"
        echo "2. カレンダーモード"
        echo "q. 終了"
        echo -n "モードを選択してください [1-2,q]: "
        
        read choice
        
        case "$choice" in
            1) todo_mode_menu ;;
            2) calendar_mode_menu ;;
            "q"|"Q") 
                echo -e "${GREEN}ありがとうございました${NC}"
                exit 0
                ;;
            *) echo -e "${RED}無効な選択です${NC}" ;;
        esac
    done
}

# ヘルプ表示
show_help() {
    echo -e "${GREEN}=== TODO管理システム ヘルプ ===${NC}"
    echo
    echo -e "${CYAN}使用法:${NC}"
    echo "  $0                    # インタラクティブメニューを表示"
    echo "  $0 todo              # TODOモード直接起動"
    echo "  $0 calendar          # カレンダーモード直接起動"
    echo "  $0 help              # このヘルプを表示"
    echo
    echo -e "${CYAN}機能概要:${NC}"
    echo -e "${YELLOW}TODOモード:${NC}"
    echo "  - プロジェクト作成・管理"
    echo "  - タスク作成・管理（階層構造対応）"
    echo "  - プライオリティ設定（高/中/低）"
    echo "  - タスク完了処理"
    echo
    echo -e "${YELLOW}カレンダーモード:${NC}"
    echo "  - 完了したタスクの履歴表示"
    echo "  - 月別表示（今月/先月/指定月）"
    echo "  - 週区分表示（土日月/火水/木金）"
    echo
    echo -e "${CYAN}データファイル:${NC}"
    echo "  - ~/.todo_data.csv      # メインデータ"
    echo "  - ~/.todo_calendar.csv  # カレンダーデータ"
    echo "  - ~/.todo_config.csv    # 設定データ"
    echo
}

# メイン実行部
main() {
    echo -e "${CYAN}TODO管理システムを起動しています...${NC}"
    
    init_files
    
    if [[ $# -eq 0 ]]; then
        main_menu
    else
        case "$1" in
            "todo") todo_mode_menu ;;
            "calendar") calendar_mode_menu ;;
            "help"|"-h"|"--help") 
                show_help
                exit 0
                ;;
            *) 
                echo "使用法: $0 [todo|calendar|help]"
                echo "引数なしで実行するとインタラクティブメニューが表示されます"
                echo "詳細は '$0 help' を参照してください"
                exit 1
                ;;
        esac
    fi
}

# スクリプト実行
main "$@"