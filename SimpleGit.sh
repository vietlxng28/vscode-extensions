#!/usr/bin/env bash

cd "$(dirname "$0")"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Lỗi: Thư mục này chưa phải là một Git repository."
    exit 1
fi

REPO_NAME=$(basename "$PWD")

has_head() {
    git rev-parse --verify HEAD >/dev/null 2>&1
}

do_status() {
    echo "===> Danh sách nhánh (Local & Remote):"
    git branch -a --format='%(if)%(HEAD)%(then)  * %(refname:short) (đang chọn)%(else)    %(refname:short)%(end)'
    echo "------------------------------"
    echo "===> Các file thay đổi:"
    if [ -z "$(git status -s)" ]; then
        echo "Không có thay đổi nào chưa lưu."
    else
        git status -s
    fi
    echo "------------------------------"
    echo "===> 5 commit gần nhất:"
    if has_head; then
        git log --oneline -n 5
    else
        echo "Chưa có commit nào."
    fi
    echo "------------------------------"
}

do_push() {
    CURRENT_BRANCH=$(git branch --show-current)
    CURRENT_DATE=$(date +"%Y-%m-%d")
    COMMIT_MESSAGE="Cập nhật ngày $CURRENT_DATE"

    echo "===> Đang kiểm tra và chuẩn bị push..."
    git add .
    if has_head && git diff-index --quiet --cached HEAD --; then
        echo "Không có thay đổi nào mới ở local."
    else
        echo "Đang tạo commit: $COMMIT_MESSAGE"
        git commit -m "$COMMIT_MESSAGE"
    fi

    echo "===> Đang cập nhật thay đổi từ remote (rebase)..."
    if ! git pull --rebase; then
        echo "Lỗi: Không thể kéo dữ liệu từ remote hoặc xảy ra xung đột."
        return
    fi

    echo "===> Đang đẩy dữ liệu lên remote..."
    if git push -u origin "$CURRENT_BRANCH"; then
        echo "===> Hoàn tất Push thành công!"
    else
        echo "Lỗi: Không thể đẩy dữ liệu lên remote."
    fi
}

do_content_push() {
    CURRENT_BRANCH=$(git branch --show-current)
    CURRENT_DATE=$(date +"%Y-%m-%d")
    COMMIT_MESSAGE="Cập nhật ngày $CURRENT_DATE"

    echo "===> Đang chuẩn bị content push (bỏ qua các file/thư mục ẩn .*)..."
    git add -A -- ':!.*' ':!.*/**'
    if has_head && git diff-index --quiet --cached HEAD --; then
        echo "Không có thay đổi mới nào (ngoài các file/thư mục ẩn) để commit."
    else
        echo "Đang tạo commit: $COMMIT_MESSAGE"
        git commit -m "$COMMIT_MESSAGE"
    fi

    echo "===> Đang đồng bộ cấu hình theo phiên bản chuẩn..."
    git checkout HEAD -- ':.*' ':.*/**' 2>/dev/null || true

    echo "===> Đang cập nhật thay đổi từ remote (rebase)..."
    if ! git pull --rebase; then
        echo "Lỗi: Không thể kéo dữ liệu từ remote hoặc xảy ra xung đột."
        return
    fi

    echo "===> Đang đẩy dữ liệu lên remote..."
    if git push -u origin "$CURRENT_BRANCH"; then
        echo "===> Hoàn tất Content Push thành công!"
    else
        echo "Lỗi: Không thể đẩy dữ liệu lên remote."
    fi
}

do_pull() {
    echo "===> Đang kéo dữ liệu mới nhất từ remote..."
    if git pull; then
        echo "===> Hoàn tất Pull thành công!"
    else
        echo "Lỗi: Không thể kéo dữ liệu từ remote."
    fi
}

do_reset_to_remote() {
    CURRENT_BRANCH=$(git branch --show-current)
    read -rp "Cảnh báo: Toàn bộ thay đổi chưa lưu ở local sẽ bị xóa để khớp 100% với remote. Tiếp tục? [y/N]: " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Đã hủy thao tác."
        return
    fi

    echo "===> Đang tải dữ liệu mới nhất từ remote..."
    if ! git fetch origin; then
        echo "Lỗi: Không thể kết nối tới remote."
        return
    fi

    echo "===> Đang ép nhánh $CURRENT_BRANCH về giống hệt origin/$CURRENT_BRANCH..."
    git reset --hard "origin/$CURRENT_BRANCH"
    git clean -fd

    echo "===> Hoàn tất ép đồng bộ giống hệt remote!"
}

do_backup() {
    CURRENT_BRANCH=$(git branch --show-current)
    BACKUP_BRANCH="backup-$(date +"%Y-%m-%d-%H%M%S")"
    CURRENT_DATE=$(date +"%Y-%m-%d")
    COMMIT_MESSAGE="Cập nhật ngày $CURRENT_DATE"

    echo "===> Đang chuẩn bị dữ liệu sao lưu..."
    git add .
    if ! has_head || ! git diff-index --quiet --cached HEAD --; then
        git commit -m "$COMMIT_MESSAGE"
    fi

    echo "===> Đang tạo nhánh sao lưu: $BACKUP_BRANCH..."
    git branch "$BACKUP_BRANCH"

    echo "===> Đang đẩy nhánh sao lưu lên remote..."
    if git push -u origin "$BACKUP_BRANCH"; then
        echo "===> Hoàn tất sao lưu thành công lên nhánh: $BACKUP_BRANCH!"
    else
        echo "Lỗi: Không thể đẩy nhánh sao lưu lên remote."
    fi

    echo "===> Đang quay về nhánh ban đầu: $CURRENT_BRANCH..."
    git checkout "$CURRENT_BRANCH"
}

do_clean_history() {
    CURRENT_BRANCH=$(git branch --show-current)
    CURRENT_DATE=$(date +"%Y-%m-%d")
    COMMIT_MESSAGE="Cập nhật ngày $CURRENT_DATE"

    read -rp "Hành động này sẽ gộp toàn bộ lịch sử thành 1 commit duy nhất và force push. Tiếp tục? [y/N]: " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Đã hủy thao tác."
        return
    fi

    echo "===> Đang gộp toàn bộ lịch sử thành 1 commit duy nhất..."
    git add .
    if ! git reset $(git commit-tree HEAD^{tree} -m "$COMMIT_MESSAGE"); then
        echo "Lỗi: Không thể reset commit tree."
        return
    fi

    echo "===> Đang đẩy đè lịch sử mới lên remote..."
    if git push --force origin "$CURRENT_BRANCH"; then
        echo "===> Hoàn tất làm sạch lịch sử commit!"
    else
        echo "Lỗi: Không thể force push lên remote."
    fi
}

do_commit_and_clean_history() {
    CURRENT_BRANCH=$(git branch --show-current)
    CURRENT_DATE=$(date +"%Y-%m-%d")
    COMMIT_MESSAGE="Cập nhật ngày $CURRENT_DATE"

    read -rp "Hành động này sẽ lưu toàn bộ thay đổi hiện tại, gộp toàn bộ lịch sử thành 1 commit duy nhất và force push. Tiếp tục? [y/N]: " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Đã hủy thao tác."
        return
    fi

    echo "===> Đang lưu tất cả thay đổi hiện tại..."
    git add .
    if ! has_head || ! git diff-index --quiet --cached HEAD --; then
        echo "Đang tạo commit: $COMMIT_MESSAGE"
        git commit -m "$COMMIT_MESSAGE"
    fi

    echo "===> Đang gộp toàn bộ lịch sử thành 1 commit duy nhất..."
    if ! git reset $(git commit-tree HEAD^{tree} -m "$COMMIT_MESSAGE"); then
        echo "Lỗi: Không thể reset commit tree."
        return
    fi

    echo "===> Đang đẩy đè lịch sử mới lên remote..."
    if git push --force origin "$CURRENT_BRANCH"; then
        echo "===> Hoàn tất lưu và làm sạch lịch sử commit!"
    else
        echo "Lỗi: Không thể force push lên remote."
    fi
}

do_set_ssh() {
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "Chưa cấu hình")
    echo "===> Remote origin hiện tại: $CURRENT_REMOTE"
    echo "Ví dụ định dạng SSH: git@github.com:username/repository.git"
    read -rp "Nhập SSH URL mới (để trống để hủy): " SSH_URL

    if [ -z "$SSH_URL" ]; then
        echo "Đã hủy thao tác."
        return
    fi

    echo "===> Đang cập nhật remote origin sang SSH..."
    if git remote set-url origin "$SSH_URL"; then
        echo "===> Hoàn tất cập nhật thành công!"
        echo "===> Remote mới: $(git remote get-url origin)"
    else
        echo "Lỗi: Không thể cập nhật remote URL."
    fi
}

pause_screen() {
    echo ""
    read -rp "Nhấn [Enter] để quay lại menu chính..." _
}

while true; do
    echo ""
    echo "=========================================="
    echo "      QUẢN LÝ GIT: $REPO_NAME             "
    echo "=========================================="
    echo "1) Status (Xem trạng thái & commit gần nhất)"
    echo "2) Push (Lưu tất cả & Đẩy lên)"
    echo "3) Content Push (Chỉ đẩy nội dung, bỏ qua file ẩn .*)"
    echo "4) Pull (Kéo dữ liệu mới về)"
    echo "5) Force Pull (Ép Local giống 100% Remote)"
    echo "6) Backup (Tạo nhánh sao lưu & Đẩy lên remote)"
    echo "7) Clean History (Gộp tất cả thành 1 commit & Force Push)"
    echo "8) Commit & Clean History (Lưu thay đổi, gộp 1 commit & Force Push)"
    echo "9) Switch to SSH (Đổi remote origin sang SSH)"
    echo "e) Thoát (Exit)"
    echo "------------------------------------------"
    read -rp "Nhập lựa chọn của bạn [1-9, e]: " CHOICE
    echo ""

    case "$CHOICE" in
        1)
            do_status
            pause_screen
            ;;
        2)
            do_push
            pause_screen
            ;;
        3)
            do_content_push
            pause_screen
            ;;
        4)
            do_pull
            pause_screen
            ;;
        5)
            do_reset_to_remote
            pause_screen
            ;;
        6)
            do_backup
            pause_screen
            ;;
        7)
            do_clean_history
            pause_screen
            ;;
        8)
            do_commit_and_clean_history
            pause_screen
            ;;
        9)
            do_set_ssh
            pause_screen
            ;;
        e|E|exit|EXIT|q|Q)
            echo "Đã thoát."
            exit 0
            ;;
        *)
            echo "Lựa chọn không hợp lệ."
            pause_screen
            ;;
    esac
done
