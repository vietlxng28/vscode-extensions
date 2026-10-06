@echo off
chcp 65001 >nul
cd /d "%~dp0"

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo Lỗi: Thư mục này chưa phải là một Git repository hoặc chưa cài Git.
    pause
    exit /b 1
)

for %%I in ("%CD%") do set "REPO_NAME=%%~nxI"

if not "%~1"=="" (
    if /i "%~1"=="status" (
        call :do_status
        exit /b %ERRORLEVEL%
    )
    if /i "%~1"=="push" (
        call :do_push
        exit /b %ERRORLEVEL%
    )
    if /i "%~1"=="content_push" (
        call :do_content_push
        exit /b %ERRORLEVEL%
    )
    if /i "%~1"=="pull" (
        call :do_pull
        exit /b %ERRORLEVEL%
    )
    if /i "%~1"=="force_pull" (
        call :do_reset_to_remote
        exit /b %ERRORLEVEL%
    )
    if /i "%~1"=="backup" (
        call :do_backup
        exit /b %ERRORLEVEL%
    )
    if /i "%~1"=="clean_history" (
        call :do_clean_history
        exit /b %ERRORLEVEL%
    )
    if /i "%~1"=="commit_clean_history" (
        call :do_commit_and_clean_history
        exit /b %ERRORLEVEL%
    )
    if /i "%~1"=="switch_ssh" (
        call :do_set_ssh
        exit /b %ERRORLEVEL%
    )
    call :%~1 2>nul
    exit /b %ERRORLEVEL%
)

:menu_loop
echo.
echo ==========================================
echo       QUẢN LÝ GIT: %REPO_NAME%
echo ==========================================
echo 1) Status (Xem trạng thái ^& commit gần nhất)
echo 2) Push (Lưu tất cả ^& Đẩy lên)
echo 3) Content Push (Chỉ đẩy nội dung, bỏ qua file ẩn .*)
echo 4) Pull (Kéo dữ liệu mới về)
echo 5) Force Pull (Ép Local giống 100%% Remote)
echo 6) Backup (Tạo nhánh sao lưu ^& Đẩy lên remote)
echo 7) Clean History (Gộp tất cả thành 1 commit ^& Force Push)
echo 8) Commit ^& Clean History (Lưu thay đổi, gộp 1 commit ^& Force Push)
echo 9) Switch to SSH (Đổi remote origin sang SSH)
echo e) Thoát (Exit)
echo ------------------------------------------
set "CHOICE="
set /p "CHOICE=Nhập lựa chọn của bạn [1-9, e]: "
echo.

if "%CHOICE%"=="" (
    echo Lựa chọn không hợp lệ.
    goto :pause_screen
)

if /i "%CHOICE%"=="1" (
    call :do_status
    goto :pause_screen
)
if /i "%CHOICE%"=="2" (
    call :do_push
    goto :pause_screen
)
if /i "%CHOICE%"=="3" (
    call :do_content_push
    goto :pause_screen
)
if /i "%CHOICE%"=="4" (
    call :do_pull
    goto :pause_screen
)
if /i "%CHOICE%"=="5" (
    call :do_reset_to_remote
    goto :pause_screen
)
if /i "%CHOICE%"=="6" (
    call :do_backup
    goto :pause_screen
)
if /i "%CHOICE%"=="7" (
    call :do_clean_history
    goto :pause_screen
)
if /i "%CHOICE%"=="8" (
    call :do_commit_and_clean_history
    goto :pause_screen
)
if /i "%CHOICE%"=="9" (
    call :do_set_ssh
    goto :pause_screen
)
if /i "%CHOICE%"=="e" goto :do_exit
if /i "%CHOICE%"=="exit" goto :do_exit
if /i "%CHOICE%"=="q" goto :do_exit

echo Lựa chọn không hợp lệ.
goto :pause_screen

:pause_screen
echo.
set "DUMMY="
set /p "DUMMY=Nhấn [Enter] để quay lại menu chính..."
goto :menu_loop

:do_status
echo ===^> Danh sách nhánh (Local ^& Remote):
git branch -a --format="%%(if)%%(HEAD)%%(then)  * %%(refname:short) (đang chọn)%%(else)    %%(refname:short)%%(end)"
echo ------------------------------
echo ===^> Các file thay đổi:
set "HAS_CHANGES="
for /f "delims=" %%i in ('git status -s') do set "HAS_CHANGES=1"
if not defined HAS_CHANGES (
    echo Không có thay đổi nào chưa lưu.
) else (
    git status -s
)
echo ------------------------------
echo ===^> 5 commit gần nhất:
git rev-parse --verify HEAD >nul 2>&1
if not errorlevel 1 (
    git log --oneline -n 5
) else (
    echo Chưa có commit nào.
)
echo ------------------------------
exit /b 0

:do_push
for /f "delims=" %%i in ('git branch --show-current') do set "CURRENT_BRANCH=%%i"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "CURRENT_DATE=%%i"
set "COMMIT_MESSAGE=Cập nhật ngày %CURRENT_DATE%"

echo ===^> Đang kiểm tra và chuẩn bị push...
git add .
git rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 goto :push_commit
git diff-index --quiet --cached HEAD --
if errorlevel 1 goto :push_commit

echo Không có thay đổi nào mới ở local.
goto :push_rebase

:push_commit
echo Đang tạo commit: %COMMIT_MESSAGE%
git commit -m "%COMMIT_MESSAGE%"

:push_rebase
echo ===^> Đang cập nhật thay đổi từ remote (rebase)...
git pull --rebase
if errorlevel 1 (
    echo Lỗi: Không thể kéo dữ liệu từ remote hoặc xảy ra xung đột.
    exit /b 1
)

echo ===^> Đang đẩy dữ liệu lên remote...
git push -u origin "%CURRENT_BRANCH%"
if not errorlevel 1 (
    echo ===^> Hoàn tất Push thành công!
    exit /b 0
) else (
    echo Lỗi: Không thể đẩy dữ liệu lên remote.
    exit /b 1
)

:do_content_push
for /f "delims=" %%i in ('git branch --show-current') do set "CURRENT_BRANCH=%%i"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "CURRENT_DATE=%%i"
set "COMMIT_MESSAGE=Cập nhật ngày %CURRENT_DATE%"

echo ===^> Đang chuẩn bị content push (bỏ qua các file/thư mục ẩn .*)...
git add -A -- ":!.*" ":!.*/**"
git rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 goto :cpush_commit
git diff-index --quiet --cached HEAD --
if errorlevel 1 goto :cpush_commit

echo Không có thay đổi mới nào (ngoài các file/thư mục ẩn) để commit.
goto :cpush_sync

:cpush_commit
echo Đang tạo commit: %COMMIT_MESSAGE%
git commit -m "%COMMIT_MESSAGE%"

:cpush_sync
echo ===^> Đang đồng bộ cấu hình theo phiên bản chuẩn...
git checkout HEAD -- ":.*" ":.*/**" 2>nul

echo ===^> Đang cập nhật thay đổi từ remote (rebase)...
git pull --rebase
if errorlevel 1 (
    echo Lỗi: Không thể kéo dữ liệu từ remote hoặc xảy ra xung đột.
    exit /b 1
)

echo ===^> Đang đẩy dữ liệu lên remote...
git push -u origin "%CURRENT_BRANCH%"
if not errorlevel 1 (
    echo ===^> Hoàn tất Content Push thành công!
    exit /b 0
) else (
    echo Lỗi: Không thể đẩy dữ liệu lên remote.
    exit /b 1
)

:do_pull
echo ===^> Đang kéo dữ liệu mới nhất từ remote...
git pull
if not errorlevel 1 (
    echo ===^> Hoàn tất Pull thành công!
    exit /b 0
) else (
    echo Lỗi: Không thể kéo dữ liệu từ remote.
    exit /b 1
)

:do_reset_to_remote
for /f "delims=" %%i in ('git branch --show-current') do set "CURRENT_BRANCH=%%i"
set "CONFIRM="
set /p "CONFIRM=Cảnh báo: Toàn bộ thay đổi chưa lưu ở local sẽ bị xóa để khớp 100%% với remote. Tiếp tục? [y/N]: "
if /i not "%CONFIRM%"=="y" (
    echo Đã hủy thao tác.
    exit /b 0
)

echo ===^> Đang tải dữ liệu mới nhất từ remote...
git fetch origin
if errorlevel 1 (
    echo Lỗi: Không thể kết nối tới remote.
    exit /b 1
)

echo ===^> Đang ép nhánh %CURRENT_BRANCH% về giống hệt origin/%CURRENT_BRANCH%...
git reset --hard "origin/%CURRENT_BRANCH%"
git clean -fd -e SimpleGit.bat

echo ===^> Hoàn tất ép đồng bộ giống hệt remote!
exit /b 0

:do_backup
for /f "delims=" %%i in ('git branch --show-current') do set "CURRENT_BRANCH=%%i"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd-HHmmss"') do set "TIMESTAMP=%%i"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "CURRENT_DATE=%%i"
set "BACKUP_BRANCH=backup-%TIMESTAMP%"
set "COMMIT_MESSAGE=Cập nhật ngày %CURRENT_DATE%"

echo ===^> Đang chuẩn bị dữ liệu sao lưu...
git add .
git rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 goto :backup_commit
git diff-index --quiet --cached HEAD --
if not errorlevel 1 goto :backup_create_branch

:backup_commit
git commit -m "%COMMIT_MESSAGE%"

:backup_create_branch
echo ===^> Đang tạo nhánh sao lưu: %BACKUP_BRANCH%...
git branch "%BACKUP_BRANCH%"

echo ===^> Đang đẩy nhánh sao lưu lên remote...
git push -u origin "%BACKUP_BRANCH%"
if not errorlevel 1 (
    echo ===^> Hoàn tất sao lưu thành công lên nhánh: %BACKUP_BRANCH%!
) else (
    echo Lỗi: Không thể đẩy nhánh sao lưu lên remote.
)

echo ===^> Đang quay về nhánh ban đầu: %CURRENT_BRANCH%...
git checkout "%CURRENT_BRANCH%"
exit /b 0

:do_clean_history
for /f "delims=" %%i in ('git branch --show-current') do set "CURRENT_BRANCH=%%i"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "CURRENT_DATE=%%i"
set "COMMIT_MESSAGE=Cập nhật ngày %CURRENT_DATE%"

set "CONFIRM="
set /p "CONFIRM=Hành động này sẽ gộp toàn bộ lịch sử thành 1 commit duy nhất và force push. Tiếp tục? [y/N]: "
if /i not "%CONFIRM%"=="y" (
    echo Đã hủy thao tác.
    exit /b 0
)

echo ===^> Đang gộp toàn bộ lịch sử thành 1 commit duy nhất...
git add .
set "NEW_COMMIT="
for /f "delims=" %%c in ('git commit-tree "HEAD^{tree}" -m "%COMMIT_MESSAGE%"') do set "NEW_COMMIT=%%c"
if not defined NEW_COMMIT (
    echo Lỗi: Không thể reset commit tree.
    exit /b 1
)

git reset %NEW_COMMIT%
if errorlevel 1 (
    echo Lỗi: Không thể reset commit tree.
    exit /b 1
)

echo ===^> Đang đẩy đè lịch sử mới lên remote...
git push --force origin "%CURRENT_BRANCH%"
if not errorlevel 1 (
    echo ===^> Hoàn tất làm sạch lịch sử commit!
    exit /b 0
) else (
    echo Lỗi: Không thể force push lên remote.
    exit /b 1
)

:do_commit_and_clean_history
for /f "delims=" %%i in ('git branch --show-current') do set "CURRENT_BRANCH=%%i"
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "CURRENT_DATE=%%i"
set "COMMIT_MESSAGE=Cập nhật ngày %CURRENT_DATE%"

set "CONFIRM="
set /p "CONFIRM=Hành động này sẽ lưu toàn bộ thay đổi hiện tại, gộp toàn bộ lịch sử thành 1 commit duy nhất và force push. Tiếp tục? [y/N]: "
if /i not "%CONFIRM%"=="y" (
    echo Đã hủy thao tác.
    exit /b 0
)

echo ===^> Đang lưu tất cả thay đổi hiện tại...
git add .
git rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 goto :cch_commit
git diff-index --quiet --cached HEAD --
if not errorlevel 1 goto :cch_squash

:cch_commit
echo Đang tạo commit: %COMMIT_MESSAGE%
git commit -m "%COMMIT_MESSAGE%"

:cch_squash
echo ===^> Đang gộp toàn bộ lịch sử thành 1 commit duy nhất...
set "NEW_COMMIT="
for /f "delims=" %%c in ('git commit-tree "HEAD^{tree}" -m "%COMMIT_MESSAGE%"') do set "NEW_COMMIT=%%c"
if not defined NEW_COMMIT (
    echo Lỗi: Không thể reset commit tree.
    exit /b 1
)

git reset %NEW_COMMIT%
if errorlevel 1 (
    echo Lỗi: Không thể reset commit tree.
    exit /b 1
)

echo ===^> Đang đẩy đè lịch sử mới lên remote...
git push --force origin "%CURRENT_BRANCH%"
if not errorlevel 1 (
    echo ===^> Hoàn tất lưu và làm sạch lịch sử commit!
    exit /b 0
) else (
    echo Lỗi: Không thể force push lên remote.
    exit /b 1
)

:do_set_ssh
set "CURRENT_REMOTE="
for /f "delims=" %%i in ('git remote get-url origin 2^>nul') do set "CURRENT_REMOTE=%%i"
if not defined CURRENT_REMOTE set "CURRENT_REMOTE=Chưa cấu hình"
echo ===^> Remote origin hiện tại: %CURRENT_REMOTE%
echo Ví dụ định dạng SSH: git@github.com:username/repository.git
set "SSH_URL="
set /p "SSH_URL=Nhập SSH URL mới (để trống để hủy): "

if "%SSH_URL%"=="" (
    echo Đã hủy thao tác.
    exit /b 0
)

echo ===^> Đang cập nhật remote origin sang SSH...
git remote set-url origin "%SSH_URL%"
if not errorlevel 1 (
    echo ===^> Hoàn tất cập nhật thành công!
    for /f "delims=" %%i in ('git remote get-url origin') do echo ===^> Remote mới: %%i
    exit /b 0
) else (
    echo Lỗi: Không thể cập nhật remote URL.
    exit /b 1
)

:do_exit
echo Đã thoát.
exit /b 0